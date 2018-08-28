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

      ignores = SiteSetting.logster_transporter_ignore_regexps
        .split("|")
        .map do |regexp|

        begin
          Regexp.new(regexp)
        rescue RegexpError => e
          Rails.logger.warn("Invalid Regexp #{e.message}: #{e.backtrace.join("\n")}")
          nil
        end
      end

      ignores.compact!

      (logs || []).each do |log|
        message = log[:message]
        next if ignores.any? { |pattern| message =~ pattern}

        Rails.logger.store.report(
          log[:severity].to_i,
          log[:progname],
          message,
          log[:opts].permit!.to_h.with_indifferent_access
        )
      end

      render json: success_json
    end
  end
end
