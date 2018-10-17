require 'logger'
require 'net/http'

module DiscourseLogsterTransporter
  class Store
    attr_reader :buffer

    PATH = '/discourse-logster-transport/receive'.freeze
    BUFFER_SIZE = 20
    FLUSH_INTERVAL = 5
    MAX_FLUSHES_PER_5_MIN = 50
    MAX_IDLE = 60

    def initialize(root_url:,
                   key:,
                   max_flush_per_5_min: MAX_FLUSHES_PER_5_MIN)

      @root_url = root_url
      @key = key
      @max_flush_per_5_min = max_flush_per_5_min
    end

    def report(severity, progname, message, opts = {})
      opts = opts.merge(backtrace: caller.join("\n"))

      # Avoid sending messages we know we don't want over the network
      return if (Logster.store.ignore || []).any? { |pattern| message =~ pattern }

      current_env =
        if opts[:env].blank?
          (Thread.current[::Logster::Logger::LOGSTER_ENV] || {})
        else
          opts[:env]
        end

      opts[:env] = ::Logster::Message.populate_from_env(current_env)
      long_hostname = `hostname -f` rescue '<unknown>'

      opts[:env] = opts[:env].merge(
        ::Logster::Message.default_env.merge("hostname" => long_hostname)
      )

      @buffer ||= RingBuffer.new(BUFFER_SIZE)

      @buffer.push({
        severity: severity,
        message: message,
        progname: progname,
        opts: opts
      })

      start_thread
    end

    def flush_buffer
      if @buffer.present? && perform_rate_limit
        yield if block_given?
        response = post

        if response.code.to_i == 200
          @buffer.clear
        else
          # TODO: Maybe we should have some form of alert?
          Rails.logger.warn("Failed to transport logs to remote instance")
        end
      end
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

    def perform_rate_limit
      RateLimiter.new(
        nil,
        "discourse_logster_transporter_#{`hostname`.strip}",
        @max_flush_per_5_min,
        600
      ).performed!(raise_error: false)
    end

    def start_thread
      return if @thread&.alive? || Rails.env.test?

      @thread = Thread.new do
        last_activity = Time.zone.now.to_i

        while (Time.zone.now.to_i - last_activity) < MAX_IDLE do
          begin
            sleep FLUSH_INTERVAL
            flush_buffer { last_activity = Time.zone.now.to_i }
          rescue => e
            raise e if Rails.env.test?

            Rails.logger.chained.first.error(
              "#{e.class} #{e.message}: #{e.backtrace.join("\n")}"
            )
          end
        end
      end

      @thread.report_on_exception = true
      @thread
    end
  end
end
