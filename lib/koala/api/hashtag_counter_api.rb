require 'koala/api/graph_api'

module Koala
  module Facebook

    module HashtagCounterAPIMethods

      # https://developers.facebook.com/docs/hashtag_counter
      # Return counts for a list of hashtags within a time window
      #
      # @param hashtags [Array<String>] array of hashtags (with leading '#')
      # @param start_time [Time] Window start (inclusive)
      # @param end_time [Time] Window end (exclusive)
      # @param opts Options
      # @return TODO
      #
      def hashtag_counts(hashtags, start_time, end_time, opts={})
        # NOTE: currently not used. offering same api as topic_counts
        opts ||= {}
        hashtags = [hashtags].flatten
        # init a mapping from request argument to a normalized version
        # {"abc": "#Abc"}
        hashtags_args_map = {}
        # map normalized version to original argument
        hashtags.each_with_index do |htag, idx|
          ntag = normalize_hashtag(htag)
          hashtags_args_map[ntag] = htag
          hashtags[idx] = ntag
        end

        # initialize return structure
        # key: hashtag (as requested by caller i.e. "#abc")
        # value: {"name": "#ABC", "count": 123}
        # {"#abc" => {"name": "#ABC", "count": 123}}
        counts_map = {}

        # TODO API enforces times "line up evenly on 300 second intervals"
        # valid: 13:00:00, 13:05:00, 13:10:00, ...
        # do anything to the args?
        start_ts = start_time.to_i
        end_ts = end_time.to_i

        # NOTE: lib currently encodes array values into comma separated strings
        # however, this api endpoint needs arg "hashtags[]" in url query string
        # including here as part of the path with time args being included in params arg
        # (added to query string by library)
        params = {
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
            # get hashtag label as returned by API
            htag_name = (hashtag_doc['hashtag'] && hashtag_doc['hashtag']['name']).to_s
            # normalize returned hashtag and map it back to requested hashtag
            htag = hashtags_args_map[normalize_hashtag(htag_name)]
            # add to return structure
            counts_map[htag] = {
              "name" => htag_name,
              "count" => hashtag_doc['count'].to_i
            }
            # entity_id = (hashtag_doc['hashtag'] && hashtag_doc['hashtag']['id']).to_s
            # if entity_id.length > 0
            #   doc["id"] = Base64.encode64("topic_#{entity_id}").chomp
            # end
          end
        end

        counts_map
      end

      private
      # to lower case, remove 1 leading '#'
      def normalize_hashtag(htag)
        strip_leading_tag(htag).downcase
      end

      def strip_leading_tag(htag)
        htag.gsub(/^\#{1}/,'')
      end

    end

  end
end
