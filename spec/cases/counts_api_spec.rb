require 'spec_helper'
require 'time'

describe 'Koala::Facebook::CountsAPIMethods' do
  include_context "Koala Graph API setup"
  before do
    @start_time = 1427130300
    @end_time = 1427166300
    @opts = {breakdown_by: ['gender'], mentions_since: @start_time, mentions_until: @end_time}
  end

  describe '#topic_counts' do
    it 'returns consistent structure' do
      topic_counts_result = @api.topic_counts(['1','#facebook'], @opts)
      expect(topic_counts_result).to be_an(Array)
      expect(topic_counts_result.length).to eq(2)
    end
  end

  describe '#topic_insights' do
    it 'chunks requests and returns an Array' do
      topic_insights_result = @api.topic_insights(['1','2'], @opts)
      expect(topic_insights_result).not_to be_nil
      expect(topic_insights_result).to be_an(Array)
      expect(topic_insights_result.length).to eq(2)

      t1 = topic_insights_result.select { |h| h['query'] == '1' }.first
      t2 = topic_insights_result.select { |h| h['query'] == '2' }.first

      expect(t1).not_to be_nil
      expect(t2).not_to be_nil

      # check that totals were summed across requests
      expect(t1['count']).to eq(6)
      expect(t2['count']).to eq(14)

      gcount_m = t1['breakdown_by'].select { |h| h['gender'] == 'male' }.first
      gcount_f = t1['breakdown_by'].select { |h| h['gender'] == 'female' }.first

      expect(gcount_m).not_to be_nil
      expect(gcount_f).not_to be_nil

      # check that breakdown values were summed respectively across requests
      expect(gcount_m['count']).to eq(2)
      expect(gcount_f['count']).to eq(4)

    end
  end

  describe '#hashtag_counts' do
    it 'returns an Array' do
      hasthtag_counts_result = @api.hashtag_counts(['#facebook'], @opts)
      expect(hasthtag_counts_result).not_to be_nil
      expect(hasthtag_counts_result).to be_an(Array)
      expect(hasthtag_counts_result.length).to eq(1)
      expect(hasthtag_counts_result.first["count"]).to eq(2)
    end
  end

end
