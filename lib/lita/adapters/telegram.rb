module Lita
  module Adapters
    class Telegram < Adapter
      attr_reader :client

      config :telegram_token, type: String, required: true

      def initialize(robot)
        super
        @client = ::Telegram::Bot::Client.new(config.telegram_token, logger: ::Logger.new($stdout))
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
					else
						bot_query = ""
					end
					
					unless bot_query.empty?
					
						if bot_query[0].match('/')
							matches, command, botname, args = bot_query.match(/\/?([^\@\s]+)(\@[^\s]+)?\s*(.+)?/).to_a
							if command.match(/start|startgroup/)
								command = args.shift!
							end
						else
							matches, botname, command, args = bot_query.match(/(#{robot.mention_name})?\s*([^\s]+)\s*(.+)?/).to_a
						end
						botname ||= robot.mention_name

						puts "botname: #{botname}, command: #{command}, args: #{args}"
						next if !botname.match(robot.mention_name)
						bot_query = "#{botname} #{command} #{args}"

						source = Lita::Source.new(user: user, room: chat)
						msg = Lita::Message.new(robot, bot_query, source)
						msg.raw = message
						robot.receive(msg)
					end
				end
			end

			def send_messages(target, messages)
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
						response = client.api.send(
							command.to_sym, 
							message
						)

						metadata.update(message_id: response["result"]["message_id"]) if metadata

					elsif message.is_a? String
						response = client.api.sendMessage(chat_id: target.room.to_i, text: message)
					else
						next
					end
				end
			end
			
			def shutdown
				Lita.logger.info "Shutting Down..."
			end

      Lita.register_adapter(:telegram, self)
    end
  end
end
