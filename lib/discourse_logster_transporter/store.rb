require 'logger'
require 'net/http'

module DiscourseLogsterTransporter
  class Store
    attr_reader :buffer

    PATH = '/discourse-logster-transport/receive'.freeze

    def initialize(root_url:, key:)
      @root_url = root_url
      @key = key
    end

    def report(severity, progname, message, opts = {})
      opts = opts.merge(backtrace: caller.join("\n"))

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

      @buffer ||= RingBuffer.new(20)

      @buffer.push({
        severity: severity,
        message: message,
        progname: progname,
        opts: opts
      })

      start_thread
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
      return if @thread&.alive? || Rails.env.test?

      @thread = Thread.new do
        last_activity = Time.zone.now.to_i

        while (Time.zone.now.to_i - last_activity) < 60 do
          begin
            sleep 5

            if @buffer.present?
              last_activity = Time.zone.now.to_i
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
