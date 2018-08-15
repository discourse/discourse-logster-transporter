module DiscourseLogsterTransporter
  class ReceiverController < ::ApplicationController
    skip_before_action :check_xhr,
                       :preload_json,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required

    def receive
      key = params.require(:key)

      if SiteSetting.logster_transporter_key.blank? ||
          key != SiteSetting.logster_transporter_key

        raise Discourse::InvalidAccess
      end

      logs = params.require(:logs)

      (logs || []).each do |log|
        Rails.logger.store.report(
          log[:severity].to_i,
          log[:progname],
          log[:message].blank? ? log[:progname] : log[:message],
          {
            env: log[:env].permit!.to_h,
            backtrace: log[:backtrace]
          }
        )
      end

      render json: success_json
    end
  end
end
