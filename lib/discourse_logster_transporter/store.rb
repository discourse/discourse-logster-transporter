require 'logger'
require 'net/http'

module DiscourseLogsterTransporter
  class Store
    attr_reader :buffer

    PATH = '/discourse-logster-transport/receive'.freeze

    def initialize(root_url:, key:)
      @buffer = RingBuffer.new(20)
      @root_url = root_url
      @key = key
      start_thread
    end

    def report(severity, progname, message, opts = {})
      opts = opts.merge(backtrace: caller.join("\n"))

      if opts[:env].blank?
        current_env = Thread.current[::Logster::Logger::LOGSTER_ENV] || {}
        opts[:env] = ::Logster::Message.populate_from_env(current_env)
      end

      long_hostname = `hostname -f` rescue '<unknown>'

      opts[:env] = opts[:env].merge(
        ::Logster::Message.default_env.merge("hostname" => long_hostname)
      )

      @buffer.push({
        severity: severity,
        message: message,
        progname: progname,
        opts: opts
      })
    end

    private

    def post
      uri = URI(@root_url)
      uri.path = PATH

      request = Net::HTTP::Post.new(
        uri,
        'Content-Type' => 'application/json'
      )

      request.body = {
        logs: @buffer,
        key: @key
      }.to_json

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http.request(request)
    end

    def start_thread
      return if Rails.env.test?

      @thread = Thread.new do
        loop do
          begin
            sleep 5

            if @buffer.present?
              response = post

              if response.code.to_i == 200
                @buffer.clear
              else
                # TODO: Maybe we should have some form of alert?
                Rails.logger.warn("Failed to transport logs to remote instance")
              end
            end
          rescue => e
            Rails.logger.chained.first.error("#{e.class} #{e.message}: #{e.backtrace.join("\n")}")
          end
        end
      end

      @thread.report_on_exception = true
      @thread
    end
  end
end
