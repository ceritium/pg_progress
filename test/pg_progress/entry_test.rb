require "test_helper"

class EntryTest < Minitest::Test
  def test_defines_all_attributes
    entry = PgProgress::Entry.new(
      pid: 1234,
      datname: "mydb",
      table_name: "users",
      command: "CREATE INDEX CONCURRENTLY",
      phase: "building index",
      progress_pct: 45.2,
      started_at: Time.now,
      duration: 120.5,
      details: { blocks_total: 1000, blocks_done: 452 }
    )

    assert_equal 1234, entry.pid
    assert_equal "mydb", entry.datname
    assert_equal "users", entry.table_name
    assert_equal "CREATE INDEX CONCURRENTLY", entry.command
    assert_equal "building index", entry.phase
    assert_equal 45.2, entry.progress_pct
    assert_equal 120.5, entry.duration
    assert_equal 1000, entry.details[:blocks_total]
  end

  def test_allows_nil_progress
    entry = PgProgress::Entry.new(
      pid: 1, datname: "db", table_name: "t", command: "VALIDATE CONSTRAINT",
      phase: "active", progress_pct: nil, started_at: nil, duration: 10.0, details: {}
    )

    assert_nil entry.progress_pct
  end

  def test_immutable
    entry = PgProgress::Entry.new(
      pid: 1, datname: "db", table_name: "t", command: "VACUUM",
      phase: "scanning heap", progress_pct: 50.0, started_at: nil, duration: nil, details: {}
    )

    assert entry.frozen?
  end

  def test_to_h
    entry = PgProgress::Entry.new(
      pid: 1, datname: "db", table_name: "t", command: "VACUUM",
      phase: "scanning heap", progress_pct: 50.0, started_at: nil, duration: nil, details: {}
    )

    hash = entry.to_h
    assert_equal 1, hash[:pid]
    assert_equal "VACUUM", hash[:command]
  end
end
