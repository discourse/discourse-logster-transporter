# frozen_string_literal: true

require "rails_helper"
require "logger"

RSpec.describe DiscourseLogsterTransporter::ReceiverController do
  class FakeStore
    attr_reader :logs

    def initialize
      @logs = []
    end

    def report(*args)
      @logs << args
    end
  end

  let(:logs) do
    [
      {
        severity: Logger::INFO.to_s,
        progname: "test",
        message: "test",
        opts: {
          env: {
            hostname: "something",
            process_id: 1234,
            application_version: "2310313",
          },
          backtrace: "something\nsomething",
        },
      },
    ]
  end

  shared_examples "invalid access" do
    it "should return the right response" do
      post "/discourse-logster-transport/receive.json", params: { logs: logs, key: key }, as: :json

      expect(response.status).to eq(403)
    end
  end

  describe "#receiver" do
    let(:logster_transporter_key) { SecureRandom.hex }
    let(:key) { logster_transporter_key }

    describe "when logster_transporter_key has not been configured" do
      it_behaves_like "invalid access"
    end

    describe "when logster_transporter_key has been configured" do
      before { SiteSetting.logster_transporter_key = logster_transporter_key }

      describe "for an incorrect key" do
        let(:key) { "ajsdajsido" }
        it_behaves_like "invalid access"
      end

      describe "when key is not present params" do
        it "returns the right response" do
          post "/discourse-logster-transport/receive.json", params: { logs: logs }, as: :json

          expect(response.status).to eq(400)
        end
      end

      describe "for a blank key" do
        let(:key) { "" }

        it "returns the right response" do
          post "/discourse-logster-transport/receive.json",
               params: {
                 logs: logs,
                 key: key,
               },
               as: :json

          expect(response.status).to eq(400)
        end
      end

      describe "when logs is not present in the params" do
        it "returns the right response" do
          post "/discourse-logster-transport/receive.json",
               params: {
                 key: logster_transporter_key,
               },
               as: :json

          expect(response.status).to eq(400)
        end
      end

      it "should log the logs correctly" do
        begin
          logs = [
            {
              severity: Logger::ERROR.to_s,
              progname: "test1",
              message: "test2",
              opts: {
                env: {
                  hostname: "something",
                  process_id: 241_213,
                  application_version: "1234566",
                },
                backtrace: "something\nsomething",
              },
            },
            {
              severity: Logger::WARN.to_s,
              progname: "test3",
              message: "",
              opts: {
                env: {
                  hostname: "something",
                  process_id: 1234,
                  application_version: "2310313",
                },
                backtrace: "something\nsomething",
              },
            },
          ]

          orig_logger = Rails.logger
          fake_store = FakeStore.new
          Rails.logger = ::Logster::Logger.new(fake_store)

          post "/discourse-logster-transport/receive.json",
               params: {
                 key: logster_transporter_key,
                 logs: logs,
               },
               as: :json

          expect(response.status).to eq(200)

          expect(fake_store.logs).to include(
            [
              Logger::ERROR,
              "test1",
              "test2",
              {
                "env" => {
                  "hostname" => "something",
                  "process_id" => 241_213,
                  "application_version" => "1234566",
                },
                "backtrace" => "something\nsomething",
              },
            ],
          )

          expect(fake_store.logs).to include(
            [
              Logger::WARN,
              "test3",
              "",
              {
                "env" => {
                  "hostname" => "something",
                  "process_id" => 1234,
                  "application_version" => "2310313",
                },
                "backtrace" => "something\nsomething",
              },
            ],
          )
        ensure
          Rails.logger = orig_logger
        end
      end
    end
  end
end
