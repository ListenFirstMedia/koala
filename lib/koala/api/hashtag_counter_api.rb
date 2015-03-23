require 'koala/api/graph_api'

module Koala
  module Facebook

    module HashtagCounterAPIMethods

      # TODO doc
      def hashtag_counts(hashtags, start_time, end_time, opts={})
        # NOTE: currently not used. offering same api as topic_counts
        opts ||= {}
        hashtags = [hashtags].flatten

        # TODO what structure to return?
        # TODO taken loosely from topic counts call
        # update that to return array structure
        hashtag_counts = []
        # hashtag_counts = {
        #   "total" => {
        #     "count" => nil
        #   }
        # }

        # TODO API enforces times "line up evenly on 300 second intervals"
        # valid: 13:00:00, 13:05:00, 13:10:00, ...
        # do anything to the args?
        start_ts = start_time.to_i
        end_ts = end_time.to_i

        # NOTE: lib currently encodes array values into comma separated strings
        # however, this api endpoint needs arg "hashtags[]" in url query string
        # including here as part of the path with times being included in params arg
        # (added to query string by library)
        params = {
          # "hashtags[]" => [...],
          "since" => start_ts,
          "until" => end_ts
        }

        # url encode each argument as part of query string params
        hashtags_query_str = hashtags.map do |arg|
          "hashtags[]=#{CGI::escape(arg)}"
        end.join('&')

        # make request for hashtag counts
        # block is called with response object that would have been returned by `get_object` call
        get_object("hashtag_counts?#{hashtags_query_str}", params, {}) do |hashtags_res|
          # iterate response Array
          # [{"count"=>"2147", "hashtag"=>{"id"=>"351255261652168", "name"=>"#MLB"}}, ...]
          hashtags_res.each do |hashtag_doc|
            # add to return structure
            hashtag_counts << {
              "name" => (hashtag_doc['hashtag'] && hashtag_doc['hashtag']['name']).to_s,
              "count" => hashtag_doc['count'].to_i
            }
          end
        end

        hashtag_counts
      end

    end

  end
end
