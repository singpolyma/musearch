$: << ::File.dirname(__FILE__)
::Dir.chdir(::File.dirname(__FILE__))
$: << File.dirname(__FILE__) + '/lib';

require 'xapian-schema'

def strip_tags(s)
	HTMLEntities.decode_entities(s.to_s.gsub(/<[^<]*>/, ' '))
end

xa = xapian_schema

xa.search(ARGV.join(' '), :phrase => true, :collapse => :id, :fields => [:category, :in_reply_to, :bookmark, :author, :published, :to]).each do |match|
p match
	puts match.values[:content_full]
	puts match.values[:to]
end
