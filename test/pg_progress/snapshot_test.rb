require "test_helper"

class SnapshotTest < Minitest::Test
  def test_capture_aggregates_all_readers
    create_index_row = [{
      "pid" => "1", "datname" => "db", "table_name" => "users",
      "index_name" => "idx", "command" => "CREATE INDEX", "phase" => "initializing",
      "lockers_total" => "0", "lockers_done" => "0", "current_locker_pid" => "0",
      "blocks_total" => "100", "blocks_done" => "50",
      "tuples_total" => "0", "tuples_done" => "0",
      "partitions_total" => "0", "partitions_done" => "0"
    }]

    vacuum_row = [{
      "pid" => "2", "datname" => "db", "table_name" => "orders",
      "phase" => "scanning heap",
      "heap_blks_total" => "200", "heap_blks_scanned" => "100",
      "heap_blks_vacuumed" => "50",
      "index_vacuum_count" => "0", "max_dead_tuples" => "0", "num_dead_tuples" => "0"
    }]

    conn = MockConnection.new(
      "pg_stat_progress_create_index" => create_index_row,
      "pg_stat_progress_vacuum" => vacuum_row,
      "pg_stat_progress_cluster" => [],
      "pg_stat_progress_analyze" => [],
      "pg_stat_activity" => [],
    )

    snapshot = PgProgress::Snapshot.capture(connection: conn)

    assert_equal 2, snapshot.entries.size
    assert_equal 1, snapshot.entries.first.pid
    assert_equal 2, snapshot.entries.last.pid
  end

  def test_for_table_filters
    entries = [
      PgProgress::Entry.new(pid: 1, datname: "db", table_name: "users", command: "VACUUM",
        phase: "scanning heap", progress_pct: 50.0, started_at: nil, duration: nil, details: {}),
      PgProgress::Entry.new(pid: 2, datname: "db", table_name: "orders", command: "VACUUM",
        phase: "scanning heap", progress_pct: 30.0, started_at: nil, duration: nil, details: {})
    ]

    snapshot = PgProgress::Snapshot.new(entries: entries)

    assert_equal 1, snapshot.for_table(:users).size
    assert_equal 1, snapshot.for_table("users").first.pid
  end

  def test_for_pid
    entries = [
      PgProgress::Entry.new(pid: 1, datname: "db", table_name: "users", command: "VACUUM",
        phase: "scanning heap", progress_pct: 50.0, started_at: nil, duration: nil, details: {}),
      PgProgress::Entry.new(pid: 2, datname: "db", table_name: "orders", command: "ANALYZE",
        phase: "initializing", progress_pct: nil, started_at: nil, duration: nil, details: {})
    ]

    snapshot = PgProgress::Snapshot.new(entries: entries)

    assert_equal "orders", snapshot.for_pid(2).table_name
    assert_nil snapshot.for_pid(999)
  end

  def test_empty
    snapshot = PgProgress::Snapshot.new(entries: [])
    assert snapshot.empty?

    snapshot_with_entries = PgProgress::Snapshot.new(entries: [
      PgProgress::Entry.new(pid: 1, datname: "db", table_name: "t", command: "VACUUM",
        phase: "x", progress_pct: nil, started_at: nil, duration: nil, details: {})
    ])
    refute snapshot_with_entries.empty?
  end

  def test_captured_at
    snapshot = PgProgress::Snapshot.new(entries: [])
    assert_instance_of Time, snapshot.captured_at
  end
end
