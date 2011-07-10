#!/usr/bin/ruby

$: << ::File.dirname(__FILE__)
::Dir.chdir(::File.dirname(__FILE__))
$: << File.dirname(__FILE__) + '/lib';

require 'htmlentities'
require 'util'
require 'from_hatom'
require 'nokogiri'
require 'xapian_schema'

def strip_tags(s)
	HTMLEntities.decode_entities(s.to_s.gsub(/<[^<]*>/, ' '))
end

xa = xapian_schema

res = fetch('http://rstat.us/updates')[1]
last_id = open(File.dirname(__FILE__) + '/db/rstatus_last_id').read
new_last_id = last_id

feed = from_hatom(res.body)

feed.each do |item|
	item = item[:item]
	bookmark = relative_to_absolute(item[:bookmark], 'http://rstat.us').to_s
	break if bookmark == last_id
	new_last_id = bookmark if new_last_id == last_id
	doc = Nokogiri::parse('<span>' + item[:content] + '</span>')
	to = doc.search('a').map {|el|
		next if el.text !~ /^@/
		{
			:url => relative_to_absolute(el.attributes['href'].to_s, 'http://rstat.us').to_s,
			:fn  => el.text[1..-1]
		}
	}.compact
	category = doc.search('a').map {|el|
		next if el.text !~ /^#/
		el.text[1..-1]
	}.compact
	item[:author][:url] = relative_to_absolute(item[:author][:url], 'http://rstat.us').to_s
	xa << {
		:content_full => item[:content],
		:content      => strip_tags(item[:content]),
		:category     => category,
		:in_reply_to  => item[:in_reply_to],
		:bookmark     => bookmark,
		:id           => bookmark,
		:author       => item[:author],
		:to           => to,
		:published    => item[:published],
		:source       => {
			:id    => item[:author][:url],
			:self  => item[:author][:url],
			:title => item[:author][:fn],
		},
	}
end


try_count = 0
begin
	xa.flush
rescue DatabaseLockError
	try_count += 1
	raise $! unless try_count < 10
	sleep 4
	retry
end

open(File.dirname(__FILE__) + '/db/rstatus_last_id', 'w') {|fh| fh.write new_last_id }
