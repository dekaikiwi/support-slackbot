module SupportBot
  module Commands
    class Support < SlackRubyBot::Commands::Base

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

      match /support-bot does <(.*)> exist in shuttlerock for <(.*)(\/)*>/ do |client, data, match|
        # SNS url
        sns_url = match[1]
        # client site url (without / at the end)
        client_site = match[2]

        client.say(channel: data.channel, text: 'I started searching...')

        per_page = 20

        base_url = "#{client_site}/v2/entries.json?per_page=#{per_page}"
        matched_entries = loop_search_by_sr_api base_url do |entry|
          source_url = entry['source']['url']
          !source_url.blank? && (source_url_matches? source_url, sns_url)
        end

        if !matched_entries.empty?
          # exist in board
          matched_entries.each do |matched_entry|
            item_id = matched_entry['id']
            client.say(channel: data.channel,
                       text: "Content exists already in board #{matched_entry['board_slug']} #{client_site}/items/#{item_id}")
          end
        else
          # search for moderation
          base_url = "#{client_site}/v2/moderations.json?token=#{ENV['SR_USER_TOKEN']}"
          puts base_url

          matched_entries = loop_search_by_sr_api base_url do |entry|
            source_url = entry['creation_explanation']['meta']['source_url']
            puts source_url
            !source_url.blank? && (source_url_matches? source_url, sns_url)
          end
          unless matched_entries.empty?
            # exist in board
            matched_entries.each do |matched_entry|
              client.say(channel: data.channel,
                         text: "Content content has been exists in moderation data with status #{matched_entry['approval_info']['approval_status']} in board #{matched_entry['board']['value']}")
            end
          end
        end
        client.say(channel: data.channel, text: 'Here is all the results')
      end

      def self.source_url_matches?(source_url, sns_url)
        twitter_url_regex = /.*twitter.com\/(.+)\/status\/(.+)(\/)+/
        if sns_url =~ twitter_url_regex
          # user_id = $1
          tweet_id = $2

          if source_url =~ twitter_url_regex
            # source_url_user_id = $1
            source_tweet_id = $2

            return tweet_id == source_tweet_id
          end
        else
          return sns_url.include? source_url
        end
      end


      def self.loop_search_by_sr_api(base_url, &block)
        per_page = 20
        page_num = 1

        # matched results
        matched_results = []
        loop {
          api_url = "#{base_url}&page=#{page_num}"
          results = Faraday.get api_url
          json_results = JSON.parse(results.body)

          json_results.each do |entry|
            matched_results.push entry if block.call entry
          end

          page_num += 1

          break if json_results.length < per_page
        }

        matched_results
      end

    end
  end
end


