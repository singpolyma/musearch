require 'nokogiri'
require 'uri'

$: << File.dirname(__FILE__)
require 'util'

# This method takes a topic URI and callback URI, discovers the PSHB hub, and sends a subscribe request
# Pass in a secret and it will use md5("#{secret}#{topic}#{secret}") as the secret
# It appends [?&]topic=#{topic} to the callback
def subscribe(topic, callback, secret=nil, &blk)
	raise 'Not a PSHB feed' unless topic
	topic, response = fetch(topic)
	# TODO: detect encoding
	if response.content_type == 'text/html'
		# Not XML, no namespace processing
		doc = Nokogiri::HTML.parse(response.body, topic.to_s, nil)
		hub = an(an(doc.at('a[rel~=hub]')).attributes)['href'].to_s
		hub = an(an(doc.at('link[rel~=hub]')).attributes)['href'].to_s unless hub && hub != ''
		new_topic = an(an(doc.at('a[rel~=self]')).attributes)['href']
		topic = new_topic.to_s if new_topic
		new_topic = an(an(doc.at('link[rel~=self]')).attributes)['href']
		topic = new_topic.to_s if new_topic
		new_topic = an(an(doc.at('a[rel~=canonical]')).attributes)['href']
		topic = new_topic.to_s if new_topic
		new_topic = an(an(doc.at('link[rel~=canonical]')).attributes)['href']
		topic = new_topic.to_s if new_topic
	else
		# XML, look for both xhtml:link, xhtml:a, and atom:link
		doc = Nokogiri::XML.parse(response.body, topic.to_s, nil)
		hub = an(an(doc.at("//xhtml:link[contains(concat(' ', normalize-space(@rel), ' '), ' hub ')]", 'xhtml' => 'http://www.w3.org/1999/xhtml')).attributes)['href'].to_s
		hub = an(an(doc.at("//atom:link[contains(concat(' ', normalize-space(@rel), ' '), ' hub ')]", 'atom' => 'http://www.w3.org/2005/Atom')).attributes)['href'].to_s unless hub && hub != ''
		new_topic = an(an(doc.at("//xhtml:a[contains(concat(' ', normalize-space(@rel), ' '), ' self ')]", 'xhtml' => 'http://www.w3.org/1999/xhtml')).attributes)['href']
		topic = new_topic.to_s if new_topic
		new_topic = an(an(doc.at("//xhtml:link[contains(concat(' ', normalize-space(@rel), ' '), ' self ')]", 'xhtml' => 'http://www.w3.org/1999/xhtml')).attributes)['href']
		topic = new_topic.to_s if new_topic
		new_topic = an(an(doc.at("//xhtml:a[contains(concat(' ', normalize-space(@rel), ' '), ' canonical ')]", 'xhtml' => 'http://www.w3.org/1999/xhtml')).attributes)['href']
		topic = new_topic.to_s if new_topic
		new_topic = an(an(doc.at("//xhtml:link[contains(concat(' ', normalize-space(@rel), ' '), ' canonical ')]", 'xhtml' => 'http://www.w3.org/1999/xhtml')).attributes)['href']
		topic = new_topic.to_s if new_topic
		new_topic = an(an(doc.at("//atom:link[contains(concat(' ', normalize-space(@rel), ' '), ' self ')]", 'atom' => 'http://www.w3.org/2005/Atom')).attributes)['href']
		topic = new_topic.to_s if new_topic
		new_topic = an(an(doc.at("//atom:link[contains(concat(' ', normalize-space(@rel), ' '), ' canonical ')]", 'atom' => 'http://www.w3.org/2005/Atom')).attributes)['href']
		topic = new_topic.to_s if new_topic
	end

	# PSHB hubs are not working right with hAtom right now, so just assume we're supposed to use autodetection
	if response.content_type =~ /html/
		alternates = {}
		doc.search('a[rel~=alternate]').to_a.reverse.each do |link|
			alternates[link.attributes['type'].to_s] = link.attributes['href'].to_s
		end
		doc.search('link[rel~=alternate]').to_a.reverse.each do |link|
			alternates[link.attributes['type'].to_s] = link.attributes['href'].to_s
		end
		return subscribe(relative_to_absolute(alternates['application/atom+xml'] || alternates['application/rss+xml'], topic), callback, secret, &blk)
	end

	raise 'Not a PSHB feed' unless hub && hub != ''
	raise 'Error discovering feed' unless topic && topic != ''

	# Let the caller do stuff before we actually subscribe, give a chance to bail out
	if block_given?
		unless (r = yield(topic))
			return r
		end
	end

	callback += (callback.index('?') ? '&' : '?') + "topic=#{u topic}"

	hub = relative_to_absolute(hub, topic)
	hub.scheme = 'https' # Try HTTPS first
	body = {'hub.callback' => callback, 'hub.mode' => 'subscribe', 'hub.topic' => topic, 'hub.verify' => 'async'}
	body['hub.secret'] = Digest::MD5.hexdigest("#{secret}#{topic}#{secret}") if secret

	response = Net::HTTP.post_form(hub, body)
	unless response.code.to_i == 202
		hub.scheme = 'http'
		response = Net::HTTP.post_form(hub, body)
		unless response.code.to_i == 202
			raise "Error on POST: #{response.body}"
		end
	end
end
