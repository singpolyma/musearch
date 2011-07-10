require 'controllers/application'
require 'lib/xapian_schema'

class IndexController < ApplicationController
	def template
		if @req['q']
			open('views/search.haml').read
		else
			open('views/index.haml').read
		end
	end

	def raw_results
		xa = xapian_schema
		@results ||= xa.search(@req['q'], :phrase => true, :collapse => :id, :fields => [:category, :in_reply_to, :bookmark, :author, :published, :to], :order => :published, :reverse => true, :limit => 10, :page => (@req['page'] || 1))
	end

	def results
		raw_results.map do |match|
			match.values
		end
	end

	def method_missing(msg, *args)
		raw_results.send(msg, *args)
	end
end
