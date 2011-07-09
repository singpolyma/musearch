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
