require "test_helper"

class ActivityReaderTest < Minitest::Test
  def test_builds_entry_for_validate_constraint
    rows = [{
      "pid" => "9012",
      "datname" => "mydb",
      "query" => "ALTER TABLE users VALIDATE CONSTRAINT fk_users_company_id",
      "state" => "active",
      "wait_event_type" => nil,
      "wait_event" => nil,
      "duration_seconds" => "521.3"
    }]

    conn = MockConnection.new("pg_stat_activity" => rows)
    entry = PgProgress::Readers::Activity.new(connection: conn).read.first

    assert_equal 9012, entry.pid
    assert_equal "users", entry.table_name
    assert_equal "VALIDATE CONSTRAINT", entry.command
    assert_equal "active", entry.phase
    assert_nil entry.progress_pct
    assert_equal 521.3, entry.duration
  end

  def test_shows_wait_event_as_phase
    rows = [{
      "pid" => "9012",
      "datname" => "mydb",
      "query" => "ALTER TABLE orders VALIDATE CONSTRAINT fk_orders_user_id",
      "state" => "active",
      "wait_event_type" => "Lock",
      "wait_event" => "ShareUpdateExclusiveLock",
      "duration_seconds" => "10.5"
    }]

    conn = MockConnection.new("pg_stat_activity" => rows)
    entry = PgProgress::Readers::Activity.new(connection: conn).read.first

    assert_equal "waiting: ShareUpdateExclusiveLock", entry.phase
  end

  def test_extracts_table_from_alter_table_only
    rows = [{
      "pid" => "1",
      "datname" => "db",
      "query" => 'ALTER TABLE ONLY "public"."payments" VALIDATE CONSTRAINT fk_payments_user_id',
      "state" => "active",
      "wait_event_type" => nil,
      "wait_event" => nil,
      "duration_seconds" => "1.0"
    }]

    conn = MockConnection.new("pg_stat_activity" => rows)
    entry = PgProgress::Readers::Activity.new(connection: conn).read.first

    assert_equal "public.payments", entry.table_name
  end
end
