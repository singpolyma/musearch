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

require 'lib/path_info_fix'
require 'lib/subdirectory_routing'
require 'lib/util'
require 'lib/xapian-schema'
require 'lib/xml_feed_polyglot'

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

	get('/pshb').head.to { |env|
		# Honestly, we want all the data :)
		[200, {}, req['hub.challenge']]
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

		meta[:author][:photo] = meta[:logo] if meta[:author] && meta[:logo]

		items.each do |item|
			to = Nokogiri::parse('<span>' + item[:content] + '</span>').search('.vcard').map {|el|
				{
					:url => el.at('.url').attributes['href'].to_s,
					:fn  => strip_tags(el.at('.fn').inner_html).strip
				}
			}
			unless item[:source]
				item[:source] = {
					:self  => meta[:self],
					:id    => meta[:id],
					:title => meta[:title]
				}
			end
			xa << {
				:content_full => item[:content],
				:content      => strip_tags(item[:content]),
				:category     => item[:category],
				:in_reply_to  => item[:in_reply_to],
				:bookmark     => item[:bookmark],
				:id           => item[:id],
				:author       => item[:author] || meta[:author],
				:to           => to,
				:published    => item[:published],
				:source       => item[:source],
			}
		end

		try_count = 0
		begin
			xa.flush
		rescue DatabaseLockError
			try_count += 1
			raise $! unless try_count < 10
			sleep 1
			retry
		end


		[200, {'Content-Type' => 'text/plain; charset=utf-8'}, "Success\n"]
	}
}
