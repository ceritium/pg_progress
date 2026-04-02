require_relative "lib/pg_progress/version"

Gem::Specification.new do |spec|
  spec.name = "pg_progress"
  spec.version = PgProgress::VERSION
  spec.authors = ["Jose Galisteo"]
  spec.summary = "Real-time monitoring of PostgreSQL operations for Rails"
  spec.description = "Monitor CREATE INDEX, VACUUM, ANALYZE, REINDEX, VALIDATE CONSTRAINT " \
                     "and other long-running PostgreSQL operations in real time. " \
                     "Reads pg_stat_progress_* views and pg_stat_activity with phase " \
                     "transition tracking and logging. Rails 7+, PostgreSQL 16+."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "railties", ">= 7.0"
end
