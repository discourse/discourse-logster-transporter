# name: discourse-logster-transporter
# about: Chains a transport logger to Logster to allow logs to be transported to a remote Discourse instance.
# version: 0.0.1
# url: https://github.com/discourse/discourse-logster-transporter

after_initialize do
  module ::DiscourseLogsterTransporter
    PLUGIN_NAME = 'discourse-logster-transporter'.freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace ::DiscourseLogsterTransporter
    end
  end
end
