require "net/ping"

def internet_connection?
  Net::Ping::External.new("8.8.8.8").ping?
end

if !internet_connection?
	puts "No internet connection!"
	exit
end

require "lita"
require "lita/metadata"
require 'telegram/bot'
require 'telegram/bot/botan'

Lita.load_locales Dir[File.expand_path(
  File.join("..", "..", "locales", "*.yml"), __FILE__
)]

require "lita/adapters/telegram"
