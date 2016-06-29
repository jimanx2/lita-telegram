require 'ohm'

module Lita
	class Metadata < Ohm::Model
		attribute :message_id
		attribute :content
		attribute :room_id
		
		index :room_id
		index :message_id
	end
end