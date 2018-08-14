require 'logger'
require 'net/http'

module DiscourseLogsterTransporter
  class Logger < ::Logger
    attr_reader :buffer

    PATH = '/logster-transport/receive'

    def initialize(root_url:, key:)
      super(nil)
      @buffer = RingBuffer.new(20)
      @root_url = root_url
      @key = key
      @thread = nil
    end

    def add(*args, &block)
      severity, message, progname = args
      message = yield if message.nil? && block_given?
      @buffer.push([severity, message, progname])
      start_thread
    end

    private

    def post(payload)
      uri = URI(@root_url)
      uri.path = PATH

      request = Net::HTTP::Post.new(
        uri,
        'Content-Type' => 'application/json'
      )

      request.body = {
        logs: @buffer,
        key: key
      }.to_json

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http.request(request)
    end

    def start_thread
      return if @thread&.alive? || Rails.env.test?

      @thread = Thread.new do
        last_activity = Time.zone.now.to_i

        while (Time.zone.now.to_i - last_activity) < 60
          sleep 5

          if @buffer.present?
            last_activity = Time.zone.now.to_i
            response = post(@buffer)

            if response.code.to_i = 200
              @buffer.clear
            else
              # TODO: Integrate an alert with https://github.com/discourse/discourse-prometheus
            end
          end
        end
      end

      @thread.report_on_exception = true
      @thread
    end
  end
end
