module Lita
  module Adapters
		class Telegram < Adapter
			attr_reader :client
			config :telegram_token, type: String, required: true
			config :webhook, type: Object, required: false, default: nil

			def initialize(robot)
				super
				bot_options = { logger: ::Logger.new($stdout) }
				bot_options[:webhook_params] = config.webhook if config.webhook
				bot_options[:method] = :webhook if config.webhook
				@client = ::Telegram::Bot::Client.new(config.telegram_token, bot_options)
			end

			def run
				client.listen do |message|
					user = Lita::User.find_by_name(message.from.username)
					user = Lita::User.create(message.from.id, {
						name: message.from.username,
						mention_name: "@#{message.from.username}",
					}) unless user

					if message.class.name == 'Telegram::Bot::Types::Message'
						chat = Lita::Room.new(message.chat.id)
						bot_query = message.text || ''
					elsif message.class.name == 'Telegram::Bot::Types::InlineQuery'
						chat = Lita::Room.new(-1)
						bot_query = "inline #{message.query}"
          elsif message.class.name == 'Telegram::Bot::Types::CallbackQuery'
            chat = Lita::Room.new(message.message.chat.id)
            bot_query = message.data
					else
						bot_query = ""
					end

					unless bot_query.empty?

            bot_query = URI.unescape( bot_query )
            
						if bot_query[0].match('/')
							matches, command, botname, args = bot_query.match(/\/?([^\@\s]+)(\@[^\s]+)?\s*(.+)?/).to_a
							if command.match(/start|startgroup/) and !args.nil?
								args = args.split(' ')
								command = args.shift
								args = args.join(' ')
							end
						else
							matches, botname, command, args = bot_query.match(/(#{robot.mention_name})?\s*([^\s]+)\s*(.+)?/).to_a
						end
						botname ||= robot.mention_name

						client.logger.info("botname: #{botname}, command: #{command}, args: #{args}")
						next if !botname.match(robot.mention_name)

						bot_query = [botname, command, args].join(' ')

						source = Lita::Source.new(user: user, room: chat)
						msg = Lita::Message.new(robot, bot_query.strip, source)
						msg.raw = message
						robot.receive(msg)
					end
				end
			end

			def send_messages(target, messages)
        responses = []
				messages.each do |message|
					if message.is_a?(Hash)
						if message.key?(:inline_query_id)
							client.api.answerInlineQuery(message)
							next
						end

						message[:chat_id] = target.room.to_i unless message.key?(:chat_id)

						action = message.delete(:withChatAction)
						metadata = message.delete(:metadata)
						command = message.delete(:command) || "sendMessage"
						
						client.api.sendChatAction(chat_id: message[:chat_id], action: action) unless action.nil?

						responses << client.api.send(
							command.to_sym, 
							message
						)
            
					elsif message.is_a? String
						responses << client.api.sendMessage(chat_id: target.room.to_i, text: message)
            
					else
						next
					end
				end
        
        responses
			end

			def shutdown
				Lita.logger.info "Shutting Down..."
			end

			Lita.register_adapter(:telegram, self)
		end
  end
end
