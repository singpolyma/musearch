require 'controllers/application'
require 'lib/subscribe'

class SubscribeController < ApplicationController
	def template
		open('views/subscribe.haml').read
	end

	def title
		super + ' - add a site'
	end

	def message
		@message
	end

	def render
		@message = 'Site added'
		begin
			subscribe(@req['topic'], ($config['approot'].split('/') + ['pshb']).join('/'), $config['secret'])
		rescue Exception
			@message = $!.message
		end
		super
	end
end
