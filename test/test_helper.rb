require "minitest/autorun"
require "active_support/core_ext/time"
require "pg_progress"

class MockConnection
  attr_reader :queries

  def initialize(results = {})
    @results = results
    @queries = []
  end

  def select_all(sql)
    @queries << sql
    key = @results.keys.find { |k| sql.include?(k) }
    @results[key] || []
  end

  def quote(value)
    "'#{value}'"
  end
end
