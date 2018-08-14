module DiscourseLogsterTransporter
  class ReceiverController < ::ApplicationController
    def receive
      key = params.require(:key)

      if SiteSetting.logster_transporter_key.blank? ||
          key != SiteSetting.logster_transporter_key

        raise Discourse::InvalidAccess
      end

      logs = params.require(:logs)

      (logs || []).each do |severity, message, progname|
        Rails.logger.add(severity, message, progname)
      end

      render json: success_json
    end
  end
end
