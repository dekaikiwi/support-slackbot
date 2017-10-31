module SupportBot
  module Commands
    class FindSNSItem < SlackRubyBot::Commands::Base

      match %r{support-bot\s*does\s*<(.*)>\s*exist\s*in\s*shuttlerock\s*for\s*<(.*)(/)*>\s*} do |client, data, match|
        # SNS url
        sns_url = match[1]
        # client site url (without / at the end)
        client_site = match[2]

        client.say(channel: data.channel, text: 'started searching...')

        # check sns exist
        connection = Faraday.new sns_url do |conn|
          conn.use FaradayMiddleware::FollowRedirects
          conn.adapter :net_http
        end

        sns_response = connection.get('')

        if sns_response.status == 404
          # sns resource not exist
          client.say(channel: data.channel, text: 'Content does not exist')
        else
          # find item in a board
          base_url = "#{client_site}/v2/entries.json?per_page=#{$sr_api_per_page}"
          matched_entries = loop_search_by_sr_api base_url do |entry|
            source_url = entry['source']['url']
            !source_url.blank? && (source_url_matches? source_url, sns_url)
          end

          if !matched_entries.empty?
            # exist in board
            matched_entries.each do |matched_entry|
              item_id = matched_entry['id']
              client.say(channel: data.channel,
                         text: "Content exists already in board #{matched_entry['board_slug']} " \
                               "#{client_site}/items/#{item_id}")
            end
          else
            # search for moderation
            base_url = "#{client_site}/v2/moderations.json?token=#{ENV['SR_USER_TOKEN']}&status_eq="

            matched_entries = loop_search_by_sr_api base_url do |entry|
              source_url = entry['creation_explanation']['meta']['source_url']
              !source_url.blank? && (source_url_matches? source_url, sns_url)
            end
            unless matched_entries.empty?
              # exist in moderation
              matched_entries.each do |matched_entry|
                client.say(channel: data.channel,
                           text: 'Content content has been exists in moderation data with status ' \
                                 "*#{matched_entry['status']}* in board " \
                                 "#{matched_entry['board']['value']}")
              end
            end
            client.say(channel: data.channel, text: 'finished searching')
          end
        end
      end

      def self.source_url_matches?(source_url, sns_url)
        twitter_url_regex = %r{.*twitter.com/(.+)/status/(.+)/*}

        # sns url conclude test except twitter
        return sns_url.include? source_url unless sns_url =~ twitter_url_regex

        tweet_id = Regexp.last_match[2]

        # source url is twitter url
        return false unless source_url =~ twitter_url_regex

        # return true if same twitter
        tweet_id == Regexp.last_match[2]

      end

      def self.loop_search_by_sr_api(base_url, &block)
        page_num = 1

        # matched results
        matched_results = []
        loop do
          api_url = "#{base_url}&page=#{page_num}"
          results = Faraday.get(api_url)
          json_results = JSON.parse(results.body)

          json_results.each do |entry|
            matched_results.push entry if block.call entry
          end

          page_num += 1

          break if json_results.length < $sr_api_per_page
        end

        matched_results
      end

    end
  end
end




