# frozen_string_literal: true

# name: discourse-logster-transporter
# about: Chains a transport logger to Logster to allow logs to be transported to a remote Discourse instance.
# version: 1.0.0
# url: https://github.com/discourse/discourse-logster-transporter

after_initialize do
  module ::DiscourseLogsterTransporter
    PLUGIN_NAME = "discourse-logster-transporter".freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace ::DiscourseLogsterTransporter
    end
  end

  require_relative "lib/ring_buffer"
  require_relative "lib/discourse_logster_transporter/store"
  require_relative "app/controllers/discourse_logster_transporter/receiver_controller"

  is_sender =
    ENV["LOGSTER_TRANSPORTER_ROOT_URL"].present? && ENV["LOGSTER_TRANSPORTER_KEY"].present?

  if !is_sender || Rails.env.test?
    ::DiscourseLogsterTransporter::Engine.routes.draw { post "/receive" => "receiver#receive" }

    Discourse::Application.routes.append do
      mount ::DiscourseLogsterTransporter::Engine, at: "/discourse-logster-transport"
    end
  end

  if is_sender && Logster.logger
    new_logger =
      Logster::Logger.new(
        DiscourseLogsterTransporter::Store.new(
          root_url: ENV["LOGSTER_TRANSPORTER_ROOT_URL"],
          key: ENV["LOGSTER_TRANSPORTER_KEY"],
        ),
      )

    new_logger.level = Logster.store.level || Logger::INFO
    Logster.logger.chain(new_logger)
  end
end
