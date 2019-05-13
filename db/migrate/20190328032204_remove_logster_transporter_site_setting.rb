# frozen_string_literal: true

class RemoveLogsterTransporterSiteSetting < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'logster_transporter_ignore_regexps'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
