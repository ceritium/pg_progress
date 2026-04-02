require "test_helper"

class ClusterReaderTest < Minitest::Test
  def test_builds_entry_from_row
    rows = [{
      "pid" => "3456",
      "datname" => "mydb",
      "table_name" => "events",
      "command" => "CLUSTER",
      "phase" => "seq scanning heap",
      "index_name" => "index_events_on_created_at",
      "heap_tuples_scanned" => "50000",
      "heap_tuples_written" => "0",
      "heap_blks_total" => "2000",
      "heap_blks_scanned" => "800",
      "index_rebuild_count" => "0"
    }]

    conn = MockConnection.new("pg_stat_progress_cluster" => rows)
    entry = PgProgress::Readers::Cluster.new(connection: conn).read.first

    assert_equal 3456, entry.pid
    assert_equal "events", entry.table_name
    assert_equal "CLUSTER", entry.command
    assert_equal "seq scanning heap", entry.phase
    assert_equal 40.0, entry.progress_pct
    assert_equal "index_events_on_created_at", entry.details[:index_name]
  end

  def test_vacuum_full_uses_cluster_view
    rows = [{
      "pid" => "7890",
      "datname" => "mydb",
      "table_name" => "logs",
      "command" => "VACUUM FULL",
      "phase" => "writing new heap",
      "index_name" => "0",
      "heap_tuples_scanned" => "100000",
      "heap_tuples_written" => "80000",
      "heap_blks_total" => "5000",
      "heap_blks_scanned" => "5000",
      "index_rebuild_count" => "0"
    }]

    conn = MockConnection.new("pg_stat_progress_cluster" => rows)
    entry = PgProgress::Readers::Cluster.new(connection: conn).read.first

    assert_equal "VACUUM FULL", entry.command
    assert_equal 100.0, entry.progress_pct
  end
end
