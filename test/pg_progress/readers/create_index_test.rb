require "test_helper"

class CreateIndexReaderTest < Minitest::Test
  def test_builds_entry_from_row
    rows = [{
      "pid" => "1234",
      "datname" => "mydb",
      "table_name" => "users",
      "index_name" => "index_users_on_email",
      "command" => "CREATE INDEX CONCURRENTLY",
      "phase" => "building index",
      "lockers_total" => "0",
      "lockers_done" => "0",
      "current_locker_pid" => "0",
      "blocks_total" => "10000",
      "blocks_done" => "4520",
      "tuples_total" => "500000",
      "tuples_done" => "226000",
      "partitions_total" => "0",
      "partitions_done" => "0"
    }]

    conn = MockConnection.new("pg_stat_progress_create_index" => rows)
    reader = PgProgress::Readers::CreateIndex.new(connection: conn)
    entries = reader.read

    assert_equal 1, entries.size

    entry = entries.first
    assert_equal 1234, entry.pid
    assert_equal "mydb", entry.datname
    assert_equal "users", entry.table_name
    assert_equal "CREATE INDEX CONCURRENTLY", entry.command
    assert_equal "building index", entry.phase
    assert_equal 45.2, entry.progress_pct
    assert_equal "index_users_on_email", entry.details[:index_name]
    assert_equal 10000, entry.details[:blocks_total]
    assert_equal 4520, entry.details[:blocks_done]
  end

  def test_progress_nil_when_blocks_total_zero
    rows = [{
      "pid" => "1", "datname" => "db", "table_name" => "t", "index_name" => "idx",
      "command" => "CREATE INDEX", "phase" => "initializing",
      "lockers_total" => "0", "lockers_done" => "0", "current_locker_pid" => "0",
      "blocks_total" => "0", "blocks_done" => "0",
      "tuples_total" => "0", "tuples_done" => "0",
      "partitions_total" => "0", "partitions_done" => "0"
    }]

    conn = MockConnection.new("pg_stat_progress_create_index" => rows)
    entry = PgProgress::Readers::CreateIndex.new(connection: conn).read.first

    assert_nil entry.progress_pct
  end

  def test_empty_when_no_operations
    conn = MockConnection.new("pg_stat_progress_create_index" => [])
    entries = PgProgress::Readers::CreateIndex.new(connection: conn).read

    assert_empty entries
  end
end
