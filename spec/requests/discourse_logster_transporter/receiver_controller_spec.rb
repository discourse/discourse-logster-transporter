require 'rails_helper'
require 'logger'

RSpec.describe DiscourseLogsterTransporter::ReceiverController do
  class FakeLogger < ::Logger
    attr_reader :logs

    def initialize
      super(nil)
      @logs = []
    end

    def store
      self
    end

    def report(*args)
      @logs << args
    end
  end

  let(:logs) do
    [
      {
        severity: '1',
        progname: 'test',
        message: 'test',
        env: {
          hostname: 'something',
          process_id: 1234,
          application_version: '2310313'
        },
        backtrace: "something\nsomething"
      }
    ]
  end

  shared_examples 'invalid access' do
    it 'should return the right response' do
      post "/discourse-logster-transport/receive.json", params: {
        logs: logs,
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
            logs: logs
          }, as: :json

          expect(response.status).to eq(400)
        end
      end

      describe 'for a blank key' do
        let(:key) { '' }

        it 'returns the right response' do
          post "/discourse-logster-transport/receive.json", params: {
            logs: logs,
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
          logs = [
            {
              severity: '4',
              progname: 'test1',
              message: 'test2',
              env: {
                hostname: 'something',
                process_id: 241213,
                application_version: '1234566'
              },
              backtrace: "something\nsomething"
            },
            {
              severity: '3',
              progname: 'test3',
              message: '',
              env: {
                hostname: 'something',
                process_id: 1234,
                application_version: '2310313'
              },
              backtrace: "something\nsomething"
            }
          ]

          orig_logger = Rails.logger
          fake_logger = FakeLogger.new
          Rails.logger = fake_logger

          post "/discourse-logster-transport/receive.json", params: {
            key: logster_transporter_key,
            logs: logs
          }, as: :json

          expect(response.status).to eq(200)
          expect(fake_logger.logs.length).to eq(2)

          first_log = fake_logger.logs.first

          expect(first_log[0]).to eq(4)
          expect(first_log[1]).to eq('test1')
          expect(first_log[2]).to eq('test2')
          expect(first_log[3].keys).to contain_exactly(:backtrace, :env)

          expect(first_log[3][:env].keys).to contain_exactly(
            "application_version", "hostname", "process_id"
          )

          second_log = fake_logger.logs.last

          expect(second_log[1]).to eq('test3')
          expect(second_log[2]).to eq('test3')
        ensure
          Rails.logger = orig_logger
        end
      end
    end
  end
end
