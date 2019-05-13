# frozen_string_literal: true

# name: discourse-logster-transporter
# about: Chains a transport logger to Logster to allow logs to be transported to a remote Discourse instance.
# version: 0.0.1
# url: https://github.com/discourse/discourse-logster-transporter

after_initialize do
  [
    '../lib/ring_buffer.rb',
    '../lib/discourse_logster_transporter/store.rb',
    '../app/controllers/discourse_logster_transporter/receiver_controller.rb',
  ].each { |path| load File.expand_path(path, __FILE__) }

  module ::DiscourseLogsterTransporter
    PLUGIN_NAME = 'discourse-logster-transporter'.freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace ::DiscourseLogsterTransporter
    end
  end

  is_sender = ENV['LOGSTER_TRANSPORTER_ROOL_URL'].present? &&
    ENV['LOGSTER_TRANSPORTER_KEY'].present?

  if !is_sender || Rails.env.test?
    ::DiscourseLogsterTransporter::Engine.routes.draw do
      post "/receive" => "receiver#receive"
    end

    Discourse::Application.routes.append do
      mount ::DiscourseLogsterTransporter::Engine, at: "/discourse-logster-transport"
    end
  end

  if is_sender && Logster.logger
    new_logger = Logster::Logger.new(
      DiscourseLogsterTransporter::Store.new(
        root_url: ENV["LOGSTER_TRANSPORTER_ROOL_URL"],
        key: ENV["LOGSTER_TRANSPORTER_KEY"]
      )
    )

    new_logger.level = Logster.store.level || Logger::INFO
    Logster.logger.chain(new_logger)
  end
end
