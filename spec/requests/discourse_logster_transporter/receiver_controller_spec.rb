require 'rails_helper'
require 'logger'

RSpec.describe DiscourseLogsterTransporter::ReceiverController do
  class FakeLogger < ::Logger
    attr_reader :logs

    def initialize
      super(nil)
      @logs = []
    end

    def add(*args, &block)
      @logs << args
    end
  end

  shared_examples 'invalid access' do
    it 'should return the right response' do
      post "/discourse-logster-transport/receive.json", params: {
        logs: [[1, 'test', 'test2']],
        key: key
      }, as: :json

      expect(response.status).to eq(403)
    end
  end

  describe '#receiver' do
    let(:logster_transporter_key) { SecureRandom.hex }
    let(:key) { logster_transporter_key }

    describe 'when logster_transporter_key has not been configured' do
      it_behaves_like "invalid access"
    end

    describe 'when logster_transporter_key has been configured' do
      before do
        SiteSetting.logster_transporter_key = logster_transporter_key
      end

      describe 'for an incorrect key' do
        let(:key) { 'ajsdajsido' }
        it_behaves_like "invalid access"
      end

      describe 'when key is not present params' do
        it 'returns the right response' do
          post "/discourse-logster-transport/receive.json", params: {
            logs: [[1, 'test', 'test2']]
          }, as: :json

          expect(response.status).to eq(400)
        end
      end

      describe 'for a blank key' do
        let(:key) { '' }

        it 'returns the right response' do
          post "/discourse-logster-transport/receive.json", params: {
            logs: [[1, 'test', 'test2']],
            key: key
          }, as: :json

          expect(response.status).to eq(400)
        end
      end

      describe 'when logs is not present in the params' do
        it 'returns the right response' do
          post "/discourse-logster-transport/receive.json", params: {
            key: logster_transporter_key
          }, as: :json

          expect(response.status).to eq(400)
        end
      end

      it "should log the logs correctly" do
        begin
          orig_logger = Rails.logger
          fake_logger = FakeLogger.new
          Rails.logger = fake_logger
          payload = [[1, 'test', 'test2'], ['2', 'test2', 'test3']]

          post "/discourse-logster-transport/receive.json", params: {
            key: logster_transporter_key,
            logs: payload
          }, as: :json

          expect(response.status).to eq(200)
          expect(fake_logger.logs).to include([1, 'test', 'test2'], [2, 'test2', 'test3'])
        ensure
          Rails.logger = orig_logger
        end
      end
    end
  end
end
