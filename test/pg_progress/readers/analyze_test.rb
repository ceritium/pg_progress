require "test_helper"

class AnalyzeReaderTest < Minitest::Test
  def test_builds_entry_from_row
    rows = [{
      "pid" => "4321",
      "datname" => "mydb",
      "table_name" => "products",
      "phase" => "acquiring sample rows",
      "sample_blks_total" => "1000",
      "sample_blks_scanned" => "780",
      "ext_stats_total" => "2",
      "ext_stats_computed" => "0",
      "child_tables_total" => "0",
      "child_tables_done" => "0",
      "current_child_table" => nil
    }]

    conn = MockConnection.new("pg_stat_progress_analyze" => rows)
    entry = PgProgress::Readers::Analyze.new(connection: conn).read.first

    assert_equal 4321, entry.pid
    assert_equal "products", entry.table_name
    assert_equal "ANALYZE", entry.command
    assert_equal "acquiring sample rows", entry.phase
    assert_equal 78.0, entry.progress_pct
    assert_equal 2, entry.details[:ext_stats_total]
  end
end
