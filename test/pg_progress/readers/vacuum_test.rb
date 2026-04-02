require "test_helper"

class VacuumReaderTest < Minitest::Test
  def test_builds_entry_from_row
    rows = [{
      "pid" => "5678",
      "datname" => "mydb",
      "table_name" => "orders",
      "phase" => "scanning heap",
      "heap_blks_total" => "10000",
      "heap_blks_scanned" => "3000",
      "heap_blks_vacuumed" => "1200",
      "index_vacuum_count" => "0",
      "max_dead_tuples" => "5000",
      "num_dead_tuples" => "150"
    }]

    conn = MockConnection.new("pg_stat_progress_vacuum" => rows)
    entry = PgProgress::Readers::Vacuum.new(connection: conn).read.first

    assert_equal 5678, entry.pid
    assert_equal "orders", entry.table_name
    assert_equal "VACUUM", entry.command
    assert_equal "scanning heap", entry.phase
    assert_equal 12.0, entry.progress_pct
    assert_equal 10000, entry.details[:heap_blks_total]
    assert_equal 1200, entry.details[:heap_blks_vacuumed]
    assert_equal 150, entry.details[:num_dead_tuples]
  end
end
