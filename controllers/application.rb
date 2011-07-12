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

	def alternates
		recognized_types.map do |type|
			next if type == @content_type
			query = @req.GET.map {|k, v|
				next if k == '_accept'
				"#{u(k)}=#{u(v)}"
			}.join('&')
			{:type => type, :href => $config['approot'] + '?' + query + '&_accept='+u(type)}
		end.compact
	end

	def render(args={})
		@content_type = args[:content_type] = @req['_accept'] || 
		                @req.accept_media_types.select {|type|
			recognized_types.index(type)
		}.first

		args[:content_type] += '; charset=utf-8' if args[:content_type]
		r = super(args)

		# Cache headers. Varnish likes Cache-Control.
		r[1].merge!({'Vary' => 'Accept', 'Cache-Control' => 'public, max-age=120', 'Expires' => (Time.now + 120).rfc2822})
		r
	end
end
