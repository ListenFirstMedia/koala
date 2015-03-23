require 'koala/api/graph_api'
require 'base64'

module Koala
  module Facebook

    module TopicAPIMethods
      # Search for a Topic Entity.
      #
      # @param name [String] the query term
      # @raise [Koala::Facebook::APIError] if the name is blank
      # @return [Array<Hash>] array of topic hashes that were found by this search query
      #
      def topic_search(name)
        search(name, {type: 'topic', fields: 'id,name,page'})
      end

      # https://developers.facebook.com/docs/topic_insights
      #
      # Fetch mention counts for a single topic ID.
      # Current Facebook API limit of total time frame <= 21600 seconds
      # This method accepts a total time frame that spans greater than API limit
      # and internally chunks api requests using maximum allowed chunk
      # counts are aggregated to the requested time window with respect to both the total
      # and full breakdowns requested
      #
      # @param topic_id [String] Facebook topic ID (use `topic_search`)
      # @param start_time [Time] Window start (inclusive)
      # @param end_time [Time] Window end (exclusive)
      # @param opts Options
      #   @option opts :breakdown_by [Array<String>] Dimensions to break down mention counts by
      # @raise [Koala::Facebook::APIError] if missing topic_id or rate limited
      # @return TODO
      #
      def topic_counts(topic_id, start_time, end_time, opts={})
        opts ||= {}

        # TODO what structure to return?
        topic_insights = {
          "total" => {
            "count" => nil
          },
          "breakdown" => []
        }

        # map for aggregating fully broken down counts across request chunks
        breakdown_map = {}

        # API request parameters
        request_params = {
          "contains_all[]" => topic_id,
          "fields" => "mentions"
        }

        # update fields with breakdown_by argument if provided
        if !(opts[:breakdown_by].nil?) && opts[:breakdown_by].length > 0
          request_params["fields"] =
            "#{request_params["fields"]}.breakdown_by(#{opts[:breakdown_by].to_s})"
        end

        # keep referance request max time
        until_time = end_time
        # TODO max chunk size given current API constraints
        chunk = 21600

        # TODO api docs makes claim that time specified must be on a five minute interval.
        # "For example, you may use 6:00 or 6:05 but not 6:02."
        # however, have not observed this to be true
        # making an idividual request with a time window of less than 5 minutes succeeds

        # start with request start time
        min_time = start_time
        # initial max time of start + chunk, or full request time window (whichever is smaller)
        max_time = [(start_time + chunk), until_time].min

        # do requests while more chunks
        while min_time < max_time
          # update since and until request parameters
          request_params['fields'] =
            "#{request_params['fields']}.since(#{min_time.to_i}).until(#{max_time.to_i})"

          # make request for this chunk of mentions counts
          insights_res = get_object('topic_insights', request_params)

          # TODO better error handling?
          arr_mentions_data = (insights_res[0]['mentions']['data'] rescue [])
          if arr_mentions_data.length > 0
            # pop the "totals" for the time period
            chunk_total = arr_mentions_data.shift

            # add this chunk's total count to totals count
            topic_insights["total"]["count"] ||= 0
            topic_insights["total"]["count"] += (chunk_total && chunk_total['count']).to_i

            # iterate breakdowns
            arr_mentions_data.each do |insight|
              # insight => {"age_range"=>"13-17", "count"=>"180", "gender"=>"male"}
              # generate a set key composed of all breakdown values that this "count" is grouped by
              # ex: "13-17|male"
              breakdown_values = opts[:breakdown_by].map{|k| insight[k]}
              breakdown_key = Base64.encode64(Marshal.dump(breakdown_values)).chomp
              # add to existing total for this breakdown grouping
              breakdown_map[breakdown_key] ||= 0
              breakdown_map[breakdown_key] += insight["count"].to_i
            end
          end

          # update chunking parameters
          min_time = max_time
          max_time = [(max_time += chunk), until_time].min
        end

        # key contains all breakdown vlaues
        # value is the summed count for the requested period
        # each key gets a hash entry in returned structure
        # with each breakdown key/value represented
        # along with our single count for the period
        # breakdown_map entry "13-17|male" becomes:
        # ex: {"age_range" => "13-17", "gender" => "male", count => <sum of chunked counts>}
        breakdown_map.each do |breakdown_key, ct|
          breakdown_entry = {}
          # load breakdown values out of breakdown_key
          breakdown_parts = Marshal.load(Base64.decode64(breakdown_key))
          breakdown_parts.each_with_index do |breakdown_value, idx|
            if breakdown_value.to_s.length > 0
              # set breakdown value for breakdown key for this entry
              # breakdown_entry["gender"] => "male"
              breakdown_entry[opts[:breakdown_by][idx]] = breakdown_value
            end
          end
          # set broken down count aggregated over request time window
          breakdown_entry["count"] = ct
          # add to response structure
          topic_insights["breakdown"] << breakdown_entry
        end

        topic_insights
      end

      # TODO add documentation
      def topic_feed(topic_id, opts={})
        opts ||= {}
        fields = "id,name,page,ranked_posts"
        post_fields = opts.delete(:fields)
        if post_fields && post_fields.length > 0
          fields = "#{fields}.fields(#{post_fields})"
        end
        params = {
          fields: fields,
        }
        get_object(topic_id, params)
      end

    end

  end
end
