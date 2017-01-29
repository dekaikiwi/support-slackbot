module SupportBot
  module Commands
    class Support < SlackRubyBot::Commands::Base
      match /^I need help with (?<topic>\w*)\$/ do |client, data, match|
        client.say(channel: data.channel, text: "You need help with #{match[:topic]} right?")
      end
    end
  end
end
