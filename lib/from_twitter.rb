require 'lib/util'
require 'json'
require 'time'

# Fetch contet from twitter search for a query
def from_twitter(q, page=1)
	uri, result = fetch("http://search.twitter.com/search.json?result_type=recent&rpp=10&page=#{page.to_i}&q=#{u(q)}")
	JSON::parse(result.body)['results'].map do |item|
		to = []
		to << {:fn => item['to_user'], :url => 'http://twitter.com/' + item['to_user']} if item['to_user']
		{
			:content_full => item['text'],
			:category     => (item['text'].scan(/#(\w+)/)[0] || []),
			:in_reply_to  => [], # This information is not in theAPI result
			:bookmark     => 'http://twitter.com/' + item['from_user'] + '/statuses/' + item['id_str'],
			:id => 'tag:twitter.com,2007:http://twitter.com/' + item['from_user'] + '/statuses/' + item['id_str'],
			:author => {
				:fn => item['from_user'],
				:url => 'http://twitter.com/' + item['from_user']
			},
			:to => to,
			:published => (Time.parse(item['created_at']) rescue Time.now),
			:source => {
				:id    => 'tag:twitter.com,2007:Status', # They all have the same id?
				:self  => 'http://twitter.com/statuses/user_timeline/' + item['from_user'] + '.atom',
				:title => 'Twitter / ' + item['from_user']
			},
		}
	end
end
