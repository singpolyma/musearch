#!/usr/bin/env rackup
# encoding: utf-8
#\ -E deployment

# load paths relative to document root
$: << ::File.dirname(__FILE__)
::Dir.chdir(::File.dirname(__FILE__))

require 'yaml'
require 'digest/md5'
require 'hmac-sha1'
require 'http_router'
require 'rack/accept_media_types'

require 'lib/xml_feed_polyglot'
require 'lib/path_info_fix'
require 'lib/subdirectory_routing'
require 'lib/util'

$config = YAML::load_file('config.yaml')

use Rack::Reloader
use Rack::ContentLength
use Rack::ShowExceptions
use PathInfoFix
use Rack::Static, :urls => ['/stylesheets'] # Serve static files if no real server is present
use SubdirectoryRouting, $config['subdirectory'].to_s

run HttpRouter.new {
	get('/?').head.to { |env|
		require 'controllers/index'
		IndexController.new(env).render
	}
=begin
	get('/pshb').head.to { |env|
		req = ::Rack::Request.new(env)
		are_subscribers = (open(File.join($config['data_dir'], u(req['topic']))).read rescue '') !~ /^\s*$/
		if req['hub.mode'] == 'subscribe' ? are_subscribers : !are_subscribers
			[200, {}, req['hub.challenge']]
		else
			[404, {'Content-Type' => 'text/plain; charset=utf-8'}, "No one wants #{req['topic']}"]
		end
	}

	post('/pshb').to lambda { |env|
		req = ::Rack::Request.new(env)
		data = env['rack.input'].read

		# Verify signature
		sig = env['HTTP_X_HUB_SIGNATURE'].to_s.sub(/^sha1=/, '')
		secret = Digest::MD5.hexdigest("#{$config['secret']}#{req.GET['topic']}#{$config['secret']}")
		unless (sig == HMAC::SHA1.new(secret).update(data).hexdigest)
			return [400, {'Content-Type' => 'text/plain; charset=utf-8'}, "Bad signature\n"]
		end

		# Set input encoding to what it has declared to be
		data = data.force_encode(req.media_type_params['charset']) if req.media_type_params['charset']
		meta = items = nil
		case req.media_type
			when 'application/rss+xml', 'application/rdf+xml', 'application/atom+xml'
				meta, items = xml_feed_polyglot(data)
			else
				return [400, {'Content-Type' => 'text/plain; charset=utf-8'}, "Cannot process #{req.media_type}\n"]
		end

		meta[:self] = req.GET['topic'] if req.GET['topic'] # We know the topic, so use it

		hatom = items.map {|i| make_hatom_item(meta, i) }.join
		open(File.join($config['data_dir'], 'tmp', Digest::MD5.hexdigest(data)), 'w') { |fh|
			fh.write hatom
		}

		[200, {'Content-Type' => 'text/plain; charset=utf-8'}, "Success\n"]
	}
=end
}
