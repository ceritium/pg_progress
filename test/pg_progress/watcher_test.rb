require "test_helper"

class WatcherTest < Minitest::Test
  def setup
    @conn = MockConnection.new
    @watcher = PgProgress::Watcher.new(interval: 1, connection: @conn)
  end

  def test_detects_new_operation
    snapshot = snapshot_with(
      PgProgress::Entry.new(pid: 1, datname: "db", table_name: "users",
        command: "CREATE INDEX CONCURRENTLY", phase: "initializing",
        progress_pct: nil, started_at: nil, duration: nil, details: {})
    )

    events = @watcher.send(:process_snapshot, snapshot)

    assert_equal 1, events.size
    assert_equal :started, events.first.type
    assert_equal "initializing", events.first.entry.phase
  end

  def test_detects_phase_change
    initial = snapshot_with(
      PgProgress::Entry.new(pid: 1, datname: "db", table_name: "users",
        command: "CREATE INDEX CONCURRENTLY", phase: "initializing",
        progress_pct: nil, started_at: nil, duration: nil, details: {})
    )
    @watcher.send(:process_snapshot, initial)

    next_phase = snapshot_with(
      PgProgress::Entry.new(pid: 1, datname: "db", table_name: "users",
        command: "CREATE INDEX CONCURRENTLY", phase: "building index",
        progress_pct: 10.0, started_at: nil, duration: nil, details: {})
    )
    events = @watcher.send(:process_snapshot, next_phase)

    assert_equal 1, events.size
    assert_equal :phase_change, events.first.type
    assert_equal "initializing", events.first.previous_phase
    assert_equal "building index", events.first.entry.phase
    assert_kind_of Float, events.first.phase_duration
  end

  def test_detects_completion
    snapshot = snapshot_with(
      PgProgress::Entry.new(pid: 1, datname: "db", table_name: "users",
        command: "VACUUM", phase: "scanning heap",
        progress_pct: 50.0, started_at: nil, duration: nil, details: {})
    )
    @watcher.send(:process_snapshot, snapshot)

    empty = snapshot_with
    events = @watcher.send(:process_snapshot, empty)

    assert_equal 1, events.size
    assert_equal :completed, events.first.type
    assert_equal "users", events.first.entry.table_name
    assert_equal "scanning heap", events.first.previous_phase
  end

  def test_no_events_when_same_phase
    entry = PgProgress::Entry.new(pid: 1, datname: "db", table_name: "users",
      command: "VACUUM", phase: "scanning heap",
      progress_pct: 50.0, started_at: nil, duration: nil, details: {})

    @watcher.send(:process_snapshot, snapshot_with(entry))
    events = @watcher.send(:process_snapshot, snapshot_with(entry))

    assert_empty events
  end

  def test_tracks_multiple_operations
    entries = [
      PgProgress::Entry.new(pid: 1, datname: "db", table_name: "users",
        command: "CREATE INDEX", phase: "initializing",
        progress_pct: nil, started_at: nil, duration: nil, details: {}),
      PgProgress::Entry.new(pid: 2, datname: "db", table_name: "orders",
        command: "VACUUM", phase: "scanning heap",
        progress_pct: 30.0, started_at: nil, duration: nil, details: {})
    ]

    events = @watcher.send(:process_snapshot, snapshot_with(*entries))

    assert_equal 2, events.size
    assert_equal [1, 2], events.map { |e| e.entry.pid }.sort
  end

  def test_phases_defined_for_all_known_commands
    %w[
      CREATE\ INDEX
      CREATE\ INDEX\ CONCURRENTLY
      REINDEX
      REINDEX\ CONCURRENTLY
      VACUUM
      VACUUM\ FULL
      CLUSTER
      ANALYZE
    ].each do |command|
      phases = PgProgress::Watcher::PHASES[command]
      refute_nil phases, "Missing phases for #{command}"
      refute_empty phases, "Empty phases for #{command}"
      assert_equal "initializing", phases.first, "First phase of #{command} should be 'initializing'"
    end
  end

  private

  def snapshot_with(*entries)
    PgProgress::Snapshot.new(entries: entries)
  end
end
