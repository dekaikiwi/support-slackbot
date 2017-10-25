$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'dotenv'
Dotenv.load

require 'slack-supportbot'
require 'trello'
require 'web'
require 'zendesk_api'

Trello.configure do |config|
  config.developer_public_key = ENV['TRELLO_API_KEY']
  config.member_token = ENV['TRELLO_MEMBER_TOKEN']
end

$zendesk_client = ZendeskAPI::Client.new do |config|
  config.url = 'https://shuttlerock.zendesk.com/api/v2'

  # Token Authentication
  config.username = ENV['ZENDESK_ACCOUNT_NAME']
  config.token = ENV['ZENDESK_ACCOUNT_TOKEN']
  config.retry = true
end

Thread.abort_on_exception = true

Thread.new do
  begin
    SupportBot::Bot.run
  rescue Exception => e
    STDERR.puts "ERROR: #{e}"
    STDERR.puts e.backtrace
    raise e
  end
end

run SupportBot::Web
