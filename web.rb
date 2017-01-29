require 'sinatra/base'

module SupportBot
  class Web < Sinatra::Base
    get '/' do
      'Support!'
    end
  end
end
