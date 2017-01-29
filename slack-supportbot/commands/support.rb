module SupportBot
  module Commands
    class Support < SlackRubyBot::Commands::Base
      match /^I need help with (.*)$/ do |client, data, match|
        searchTerm = match[1]

        results = Trello::Action.search("board:\"Questions for the Tech Team\" #{searchTerm}")

        if results["cards"].length
          attachments = []
          cards = results["cards"]

          cards.each do |card|
            attachments.push({
                title: card.name,
                title_link: card.short_url[0, 20],
                text: "#{card.desc[0, 100]}...",
                fallback: card.name,
                thumb_url: "https://s3.amazonaws.com/trello/images/og/trello-icon.png?v=2013-08-15"
              })
          end

          client.say(channel: data.channel, text: "<@#{data.user}> Hey I found some information that might be useful! I'll send it to you in a thread ;)")
          client.web_client.chat_postMessage(
            channel: data.channel,
            as_user: true,
            attachments: attachments,
            thread_ts: data.ts,
          )

        else
          client.say(channel: data.channel, text: "<@#{data.user}> Hmm... I couldn't find anything sorry!")
        end
      end
    end
  end
end
