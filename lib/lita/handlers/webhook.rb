require 'multi_json'

class Lita::Handlers::Webhook < Lita::Handler

	http.post "/" do |request, response|
		
		Lita.logger.info request.body
		
		update = Telegram::Bot::Types::Update.new MultiJson.load(request.body)
		message = extract_message(update)
		
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
				if command.match(/start|startgroup/) and !args.nil?
					args = args.split(' ')
					command = args.shift
					args = args.join(' ')
				end
			else
				matches, botname, command, args = bot_query.match(/(#{robot.mention_name})?\s*([^\s]+)\s*(.+)?/).to_a
			end
			botname ||= robot.mention_name

			Lita.logger.info("botname: #{botname}, command: #{command}, args: #{args}")
			next if !botname.match(robot.mention_name)

			bot_query = [botname, command, args].join(' ')

			source = Lita::Source.new(user: user, room: chat)
			msg = Lita::Message.new(robot, bot_query.strip, source)
			msg.raw = message
			robot.receive(msg)
		end
	end
	
	private
	def extract_message(update)
		update.inline_query ||
			update.chosen_inline_result ||
			update.callback_query ||
			update.edited_message ||
			update.message
	end
end