require "active_record"
require_relative "pg_progress/version"
require_relative "pg_progress/entry"
require_relative "pg_progress/readers/base"
require_relative "pg_progress/readers/create_index"
require_relative "pg_progress/readers/vacuum"
require_relative "pg_progress/readers/cluster"
require_relative "pg_progress/readers/analyze"
require_relative "pg_progress/readers/activity"
require_relative "pg_progress/snapshot"
require_relative "pg_progress/watcher"

module PgProgress
  def self.snapshot(connection: ActiveRecord::Base.connection)
    Snapshot.capture(connection: connection)
  end

  def self.watch(interval: 2, connection: ActiveRecord::Base.connection, &block)
    Watcher.new(interval: interval, connection: connection).run(&block)
  end
end

require_relative "pg_progress/railtie" if defined?(Rails::Railtie)
