#encoding: utf-8
require 'net/https'

# Eat nils
def an(o)
        if o.nil?
                Class.new {
                        def method_missing(*args)
                                nil
                        end
                }.new
        else
                o
        end
end

def strip_tags(s)
	HTMLEntities.decode_entities(s.to_s.gsub(/<[^<]*>/, ''))
end

# URI encode a string, based on CGI module
def u(string)
	string.gsub(/([^a-zA-Z0-9_.-]+)/n) do
		'%' + $1.unpack('H2' * $1.size).join('%').upcase
	end
end

# HTML/XML escape a string, based on CGI module
def h(string)
	string.gsub(/&/, '&amp;').gsub(/\"/, '&quot;').gsub(/>/, '&gt;').gsub(/</, '&lt;')
end

# Convert relative URI to absolute URI
def relative_to_absolute(uri, relative_to)
	return nil unless uri
	uri = URI::parse(uri) unless uri.is_a?(URI)
	relative_to = URI::parse(relative_to) unless relative_to.is_a?(URI)
	return uri if uri.scheme
	uri.scheme = relative_to.scheme
	uri.host = relative_to.host
	if uri.path.to_s[0,1] != '/'
		uri.path = "/#{uri.path}" unless relative_to.path[-1,1] == '/'
		uri.path = "#{relative_to.path}#{uri.path}"
	end
	uri
end

# Basic HTTP recursive fetch function (follows redirects)
def fetch(topic, fetch=nil, temp=false)
	fetch = topic unless fetch
	fetch = URI::parse(fetch) unless fetch.is_a?(URI)
	fetch.path = '/' if fetch.path.to_s == ''
	response = nil
	http = Net::HTTP.new(fetch.host, fetch.port)
	http.use_ssl = true if fetch.scheme == 'https'
	http.start {
		response = http.get(fetch.request_uri, {
			'User-Agent' => 'µsearch.singpolyma.net',
			'Accept' => 'application/rss+xml, application/atom+xml, application/rdf+xml, application/xhtml+xml, text/html; q=0.9'
		})
	}
	case response.code.to_i
		when 301 # Treat 301 as 302 if we have temp redirected already
			response['location'] = relative_to_absolute(response['location'], fetch).to_s
			fetch(temp ? topic : response['location'], response['location'], temp)
		when 302, 303, 307
			response['location'] = relative_to_absolute(response['location'], fetch).to_s
			fetch(topic, response['location'], true)
		when 200
			charset = response['content-type'].to_s.scan(/charset=([\w-]+)/)[0][0] rescue nil
			if !charset && response['content-type'].to_s =~ /html/
				charset = response.body.scan(/charset=\"?([\w-]+)/)[0][0] rescue nil
			end
			if charset
				response.body = response.body.force_encoding(charset).encode('utf-8', :undef => :replace) rescue response.body.force_encoding('utf-8')
			else
				response.body.force_encoding('utf-8')
			end
			response.body = response.body.force_encoding('binary').encode('utf-8', :undef => :replace) unless response.body.valid_encoding?
			[topic, response]
		else
			raise response.body
	end
end

