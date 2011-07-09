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

	def results
		xa = xapian_schema
		xa.search(@req['q'], :phrase => true, :collapse => :id,
		          :fields => [:category, :in_reply_to, :bookmark, :author, :published, :to],
		          :order => :published, :reverse => true).map do |match|
			match.values
		end
	end
end
