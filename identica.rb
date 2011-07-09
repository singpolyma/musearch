#!/usr/bin/ruby

$: << ::File.dirname(__FILE__)
::Dir.chdir(::File.dirname(__FILE__))
$: << File.dirname(__FILE__) + '/lib';

require 'htmlentities'
require 'util'
require 'xml_feed_polyglot'
require 'nokogiri'
require 'xapian_schema'

def strip_tags(s)
	HTMLEntities.decode_entities(s.to_s.gsub(/<[^<]*>/, ' '))
end

xa = xapian_schema

res = fetch('http://identi.ca/api/statuses/public_timeline.atom')[1]
last_id = open(File.dirname(__FILE__) + '/db/identica_last_id').read
new_last_id = last_id

meta, feed = xml_feed_polyglot(res.body)

feed.each do |item|
	break if item[:id] == last_id
	new_last_id = item[:id] if new_last_id == last_id
	to = Nokogiri::parse('<span>' + item[:content] + '</span>').search('.vcard').map {|el|
		{
			:url => el.at('.url').attributes['href'].to_s,
			:fn  => strip_tags(el.at('.fn').inner_html).strip
		}
	}
	xa << {
		:content_full => item[:content],
		:content      => strip_tags(item[:content]),
		:category     => item[:category],
		:in_reply_to  => item[:in_reply_to],
		:bookmark     => item[:bookmark],
		:id           => item[:id],
		:author       => item[:author],
		:to           => to,
		:published    => item[:published],
		:source       => item[:source],
	}
end

xa.flush

open(File.dirname(__FILE__) + '/db/identica_last_id', 'w') {|fh| fh.write new_last_id }
