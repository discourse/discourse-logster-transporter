# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseLogsterTransporter::Store do
  let(:root_url) { "https://test.somesite.org" }
  let(:store) { described_class.new(root_url: root_url, key: "") }

  before do
    @logster_ignore = Logster.store.ignore
    Logster.store.ignore = [/ActionController/]
  end

  after { Logster.store.ignore = @logster_ignore }

  describe "#report" do
    it "should add the right message into the buffer" do
      store.report(Logger::WARN, "test", "test", test: "testing", backtrace: "hello")

      store.report(Logger::ERROR, "test2", "test2")
      store.report(Logger::ERROR, "progname", "ActionController")

      expect(store.buffer.length).to eq(2)

      first_log = store.buffer.first

      expect(first_log[:severity]).to eq(2)
      expect(first_log[:message]).to eq("test")
      expect(first_log[:progname]).to eq("test")
      expect(first_log[:opts][:test]).to eq("testing")
      expect(first_log[:opts][:backtrace]).to eq("hello")
      expect(first_log[:opts][:env]["hostname"]).to eq(Socket.gethostname)

      second_log = store.buffer.last

      expect(second_log[:opts].keys).to contain_exactly(:backtrace, :env)

      expect(second_log[:opts][:env].keys).to contain_exactly(
        "application_version",
        "process_id",
        "hostname",
      )
    end
  end

  describe "#flush_buffer" do
    let(:store) { described_class.new(root_url: root_url, key: "", max_flush_per_5_min: 1) }

    before { RateLimiter.enable }

    after do
      RateLimiter.disable
      $redis.flushall
    end

    it "can rate limit flush rate" do
      stub_request(:post, "#{root_url}#{described_class::PATH}").to_return(
        status: 200,
        body: "",
        headers: {
        },
      )

      store.report(Logger::ERROR, "test2", "test2")
      store.flush_buffer

      expect(store.buffer).to eq([])

      store.report(Logger::ERROR, "test2", "test2")
      store.flush_buffer

      expect(store.buffer.size).to eq(1)
    end
  end
end
