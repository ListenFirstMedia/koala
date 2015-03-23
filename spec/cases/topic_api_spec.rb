require 'spec_helper'

describe 'Koala::Facebook::TopicAPIMethods' do
  before do
    @api = Koala::Facebook::API.new(@token)
    # app API
    @app_id = KoalaTest.app_id
    @app_access_token = KoalaTest.app_access_token
    @app_api = Koala::Facebook::API.new(@app_access_token)
  end

  describe '#topic_search' do
    it 'returns topic search results Koala::Facebook::API::GraphCollection' do
      response = @api.topic_search('lfm')
      expect(response.length).to eq(1)
      expect(response.first['name']).to eq("ListenFirst Media")
    end
  end

end
