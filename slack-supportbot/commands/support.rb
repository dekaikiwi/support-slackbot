module SupportBot
  module Commands
    class Support < SlackRubyBot::Commands::Base

      def search_all_boards(client_site, match_url)
        per_page = 20
        page_num = 1
        base_url = "#{client_site}/v2/entries.json&per_page=#{per_page}"

        loop {
          api_url = base_url + "&page=#{page_num}"
          results = Faraday.get api_url
          results.each do |entry|
            entry if entry['source']['url'] == match_url
          end

          return nil if results.empty?
          page_num += 1
        }

      end

      match /I need help with (.*)$/ do |client, data, match|
        search_term = match[1]

        # results from Trello
        trello_results = Trello::Action.search(search_term)

        # results from Zendesk
        zendesk_results = $zendesk_client.search(:query => search_term).fetch

        # return results
        if trello_results["cards"].length > 0 || zendesk_results.count > 0

          # for trello
          attachments = []
          cards = trello_results["cards"]

          # send messages from trello
          cards.each do |card|
            attachments.push({
                title: card.name[0, 50],
                title_link: card.short_url,
                text: "#{card.desc[0, 100]}...",
                fallback: card.name,
                thumb_url: "https://s3.amazonaws.com/trello/images/og/trello-icon.png?v=2013-08-15"
              })
          end

          client.say(channel: data.channel,
                     text: "<@#{data.user}> Hey I found some information that might be useful! I'll send it to you in a thread ;)")
          unless attachments.empty?
            client.web_client.chat_postMessage(
              channel: data.channel,
              as_user: true,
              attachments: attachments,
              thread_ts: data.ts,
            )
          end

          # for zendesk
          attachments = []
          zendesk_results.each do |result|
            attachments.push({
              title: result.subject,
              title_link: result.url,
              text: "#{result.description}",
              raw_subject: result.subject,
              thumb_url: "https://s3.amazonaws.com/static.shuttlerock.com/images/social-user-icons/zendesk.png"
            })
          end

          # send messages of zendesk
          unless attachments.empty?
            client.web_client.chat_postMessage(
              channel: data.channel,
              as_user: true,
              attachments: attachments,
              thread_ts: data.ts,
            )
          end

        else
          client.say(channel: data.channel, text: "<@#{data.user}> Hmm... I couldn't find anything sorry!")
        end
      end

      match /support-bot does (.*) exist in shuttlerock for (.*)/ do |client, data, match|
        # SNS url
        url = match[1]
        # client site url
        client_site = match[2]

        matched_entry = self.search_all_boards(client_site, url)
        unless matched_entry.nil?
          client.say(channel: data.channel,
                     text: "Content exists already in board #{matched_entry['board_slug']} #{client_site + '/' + matched_entry['board_slug']}")
        end

      end


    end
  end
end
