## TEMPORARY UNTIL MERGE
require 'yaml'

class Array #:nodoc:
	def self.to_xapian_fu_storage_value(value)
		YAML::dump(value)
	end

	def self.from_xapian_fu_storage_value(value)
		YAML::load(value) rescue nil
	end
end

class Hash #:nodoc:
	def self.to_xapian_fu_storage_value(value)
		YAML::dump(value)
	end

	def self.from_xapian_fu_storage_value(value)
		YAML::load(value) rescue nil
	end
end

module XapianFu
	class ResultSet < Array
		def initialize(options = { })
			@mset = options[:mset]
			@current_page = options[:current_page]
			@per_page = options[:per_page]
			@corrected_query = options[:corrected_query]
			concat mset.matches.collect { |m| XapianDoc.new(m, :xapian_db => options[:database]) }
		end
	end

	class XapianDb
		def search(q, options = {})
			defaults = { :page => 1, :reverse => false,
				:boolean => true, :boolean_anycase => true, :wildcards => true,
				:lovehate => true, :spelling => spelling, :pure_not => false }
			options = defaults.merge(options)
			page = options[:page].to_i rescue 1
			page = page > 1 ? page - 1 : 0
			per_page = options[:per_page] || options[:limit] || 10
			per_page = per_page.to_i rescue 10
			offset = page * per_page
			qp = XapianFu::QueryParser.new({ :database => self }.merge(options))
			query = qp.parse_query(q.to_s)
			enquiry = Xapian::Enquire.new(ro)
			setup_ordering(enquiry, options[:order], options[:reverse])
			if options[:collapse]
				enquiry.collapse_key = XapianDocValueAccessor.value_key(options[:collapse])
			end
			enquiry.query = query
			ResultSet.new(:mset => enquiry.mset(offset, per_page), :current_page => page + 1,
										:per_page => per_page, :corrected_query => qp.corrected_query,
										:database => self)
		end
	end
end
## END TEMP SECTION

require 'xapian-fu'

def xapian_schema
	XapianFu::XapianDb.new(:dir => 'db/', :create => true, :fields =>
		{
			:content_full => { :type => String, :store => true, :index => false },
			:content      => { :type => String, :store => false, :index => true },
			:category     => { :type => Array,  :store => true },
			:in_reply_to  => { :type => Array,  :store => true },
			:bookmark     => { :type => String, :store => true },
			:id           => { :type => String, :store => true, :index => false },
			:author       => { :type => Hash,   :store => true },
			:to           => { :type => Array,  :store => true },
			:published    => { :type => Time,   :store => true },
			:source       => { :type => Hash,   :store => true, :index => false },
		}
	)
end
