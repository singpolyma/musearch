require 'controllers/application'
require 'lib/xapian_schema'
require 'lib/from_twitter'

class IndexController < ApplicationController
	def template
		if @req['q']
			if @content_type == 'application/atom+xml'
				open('views/feed.haml').read
			else
				open('views/search.haml').read
			end
		else
			open('views/index.haml').read
		end
	end

	def recognized_types
		if @req['q']
			['text/html', 'application/xhtml+xml', 'application/atom+xml']
		else
			['text/html', 'application/xhtml+xml']
		end
	end

	def raw_results
		begin
			@twitter ||= from_twitter(@req['q'], @req['page'] || 1)
		rescue Exception
			@twitter = [] # Do not fail if twitter is down
		end
		xa = xapian_schema
		@results ||= xa.search(@req['q'], :phrase => true, :collapse => :id, :fields => [:content, :category, :in_reply_to, :bookmark, :author, :published, :to], :order => :published, :reverse => true, :limit => 10, :page => (@req['page'] || 1))
	end

	def results
		(raw_results.map do |match|
			match.values
		end + @twitter).sort {|a,b| b[:published]<=> a[:published]}
	end

	def method_missing(msg, *args)
		raw_results.send(msg, *args)
	end
end
