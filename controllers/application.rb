# encoding: utf-8
require 'lib/haml_controller'

class ApplicationController < HamlController
	def initialize(env)
		super()
		@env = env
		@req = Rack::Request.new(env)
	end

	def recognized_types
		['text/html', 'application/xhtml+xml']
	end

	def title
		'µsearch'
	end

	def stylesheets
		['/stylesheets/main.css']
	end

	def render(args={})
		return @error if @error

		args[:content_type] = @req.accept_media_types.select { |type|
			recognized_types.index(type)
		}.first

		#case args[:content_type]
		#	else
				args[:content_type] += '; charset=utf-8' if args[:content_type]
				super(args)
		#end
	end
end
