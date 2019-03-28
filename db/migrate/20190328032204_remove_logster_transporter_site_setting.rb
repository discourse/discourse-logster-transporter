class RemoveLogsterTransporterSiteSetting < ActiveRecord::Migration[5.2]
  def change
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'logster_transporter_ignore_regexps'
    SQL
  end
end
