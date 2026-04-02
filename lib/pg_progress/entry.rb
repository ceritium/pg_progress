module PgProgress
  Entry = Data.define(
    :pid,           # Integer — PG backend PID
    :datname,       # String — database name
    :table_name,    # String — target table
    :command,       # String — e.g. "CREATE INDEX CONCURRENTLY", "VACUUM", "VALIDATE CONSTRAINT"
    :phase,         # String — current phase
    :progress_pct,  # Float or nil — 0.0-100.0, nil when not measurable
    :started_at,    # Time or nil — when the operation started (from pg_stat_activity.query_start)
    :duration,      # Float or nil — seconds since operation started
    :details        # Hash — raw columns from the pg_stat_progress_* view
  )
end
