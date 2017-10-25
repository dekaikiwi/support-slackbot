module SupportBot
  module Commands
    class Support < SlackRubyBot::Commands::Base

      match /I need help with (.*)$/ do |client, data, match|
        searchTerm = match[1]

        # results from Trello
        trello_results = Trello::Action.search(searchTerm)

        # results from Zendesk
        zendesk_results = $zendesk_client.search(:query => searchTerm).fetch

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

          client.say(channel: data.channel, text: "<@#{data.user}> Hey I found some information that might be useful! I'll send it to you in a thread ;)")
          if attachments.length > 0
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
          if attachments.length > 0
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
    end
  end
end
