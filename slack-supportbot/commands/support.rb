module SupportBot
  module Commands
    class Support < SlackRubyBot::Commands::Base

      match /I need help with (.*)$/ do |client, data, match|
        limit_for_result = 5
        search_term = match[1]

        # results from Trello
        trello_results = Trello::Action.search(search_term, cards_limit: limit_for_result)

        # results from Zendesk
        zendesk_results = $zendesk_client.search(query: search_term).fetch

        # confluence
        confluence_conn = Faraday.new('https://shuttlerock.atlassian.net/wiki/') do |config|
          config.request :url_encoded
          config.adapter Faraday.default_adapter
          config.basic_auth(ENV['CONFLUENCE_USER_NAME'], ENV['CONFLUENCE_USER_PASSWORD'])
        end
        confluence_query_url = "rest/api/content/search?cql=title~#{search_term}%20or%20text~#{search_term}"
        confluence_response = confluence_conn.get confluence_query_url
        confluence_json_results = JSON.parse(confluence_response.body)['results']

        # return results
        if !trello_results['cards'].empty? || !zendesk_results.empty? || !confluence_json_results.empty?

          # trello
          attachments = []
          cards = trello_results['cards']

          # send messages from trello
          cards.each do |card|
            attachments.push(
                title: card.name[0, 50],
                title_link: card.url,
                text: "#{card.desc[0, 100]}...",
                fallback: card.name,
                thumb_url: 'https://s3.amazonaws.com/trello/images/og/trello-icon.png?v=2013-08-15',
            )
          end

          client.say(channel: data.channel,
                     text: "<@#{data.user}> Hey I found some information that might be useful! I'll send it to you in a thread ;)")
          send_a_private_thread(client, data, attachments) unless attachments.empty?

          # zendesk
          attachments = []
          zendesk_results.slice(0, limit_for_result).each do |result|
            attachments.push(
                title: result.subject,
                title_link: result.url,
                text: "#{result.description[0, 100]}...",
                raw_subject: result.subject,
                thumb_url: "https://s3.amazonaws.com/static.shuttlerock.com/images/social-user-icons/zendesk.png",
            )
          end
          send_a_private_thread(client, data, attachments) unless attachments.empty?

          # send confluence results
          attachments = []
          confluence_json_results.slice(0, limit_for_result).each do |result|
            attachments.push(
                title: result['title'],
                title_link: "https://shuttlerock.atlassian.net/wiki#{result['_links']['webui']}",
                text: result['title'],
                raw_subject: result['title'],
                thumb_url: 'https://s3.amazonaws.com/static.shuttlerock.com/images/social-user-icons/confluence.png',
            )
          end
          send_a_private_thread(client, data, attachments) unless confluence_json_results.empty?
        else
          client.say(channel: data.channel, text: "<@#{data.user}> Hmm... I couldn't find anything sorry!")
        end
      end

      def self.send_a_private_thread(client, data, attachments)
        client.web_client.chat_postMessage(
            channel: data.channel,
            as_user: true,
            attachments: attachments,
            thread_ts: data.ts,
        )
      end
    end
  end
end


