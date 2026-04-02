# PgProgress

Real-time monitoring of long-running PostgreSQL operations for Rails. Track the progress of `CREATE INDEX CONCURRENTLY`, `VACUUM`, `ANALYZE`, `REINDEX`, `VALIDATE CONSTRAINT` and more — with phase-by-phase detail.

No tables. No migrations. No background jobs. Just reads PostgreSQL's built-in progress views.

## Requirements

- Ruby >= 3.2
- Rails >= 7.0
- PostgreSQL >= 16

## Installation

Add to your Gemfile:

```ruby
gem "pg_progress", github: "ceritium/pg_progress"
```

## Usage

### Snapshot

Take a point-in-time snapshot of all running operations:

```ruby
PgProgress.snapshot                          # all operations
PgProgress.snapshot.for_table(:users)        # filter by table
PgProgress.snapshot.for_pid(1234)            # find by PID
PgProgress.snapshot.empty?                   # anything running?
```

Each entry in the snapshot is a `PgProgress::Entry` with:

```ruby
entry.pid            # PG backend PID
entry.command        # "CREATE INDEX CONCURRENTLY", "VACUUM", etc.
entry.table_name     # target table
entry.phase          # current phase (e.g. "building index")
entry.progress_pct   # 0.0-100.0, or nil when not measurable
entry.started_at     # when the operation started
entry.duration       # seconds elapsed
entry.details        # raw data from the pg_stat_progress_* view
```

### Rake tasks

```bash
# Point-in-time status with phase detail
rails pg_progress:status

# Live watch with phase transitions
rails pg_progress:watch
rails pg_progress:watch[5]  # poll every 5 seconds
```

#### Example output: `rails pg_progress:status`

```
CREATE INDEX CONCURRENTLY index_users_on_email (PID 1234) — started 14:23:07 (3m 22.1s)
  ✓ initializing
  ✓ waiting for writers before build
  ► building index: scanning table [45.2%]
    building index: sorting live tuples
    building index: loading tuples in tree
    waiting for writers before validation
    index validation: scanning index
    index validation: sorting tuples
    index validation: scanning table
    waiting for old snapshots
    waiting for readers before marking dead
    waiting for readers before dropping

VACUUM orders (PID 5678) — started 14:25:24 (1m 5.3s)
  ✓ initializing
  ► scanning heap [12.0%]
    vacuuming indexes
    vacuuming heap
    cleaning up indexes
    truncating heap
    performing final cleanup

VALIDATE CONSTRAINT fk_users_company (PID 9012) — started 14:17:48 (8m 41.3s)
  ► active
```

### Watch mode

The watch mode polls every N seconds and tracks phase transitions over time. Completed phases show their duration:

```
CREATE INDEX CONCURRENTLY index_users_on_email (PID 1234)
  ✓ initializing                              0.1s
  ✓ waiting for writers before build          2.3s
  ► building index: scanning table            3m 22s  [45.2%]
    building index: sorting live tuples
    ...
```

Phase transitions are logged to `Rails.logger`:

```
[PgProgress] CREATE INDEX CONCURRENTLY index_users_on_email (PID 1234) started — phase: initializing
[PgProgress] CREATE INDEX CONCURRENTLY index_users_on_email (PID 1234) phase: initializing -> waiting for writers before build (0.1s)
[PgProgress] CREATE INDEX CONCURRENTLY index_users_on_email (PID 1234) phase: waiting for writers before build -> building index: scanning table (2.3s)
```

### Watch with callbacks

```ruby
PgProgress.watch(interval: 2) do |event|
  case event.type
  when :started
    Slack.notify("#{event.entry.command} started on #{event.entry.table_name}")
  when :phase_change
    # event.previous_phase, event.phase_duration available
  when :completed
    Slack.notify("#{event.entry.command} on #{event.entry.table_name} completed")
  end
end
```

### Multi-database support

For Rails multi-database apps, database-specific tasks are generated automatically (same convention as `rails db:migrate:animals`):

```bash
rails pg_progress:status:animals
rails pg_progress:watch:animals
rails pg_progress:watch:animals[5]
```

From Ruby:

```ruby
PgProgress.snapshot(connection: AnimalsRecord.connection)
PgProgress.watch(connection: AnimalsRecord.connection)
```

## Data sources

### Operations with progress tracking (via `pg_stat_progress_*`)

| Operation | View | Progress metric |
|-----------|------|-----------------|
| CREATE INDEX / REINDEX | `pg_stat_progress_create_index` | blocks_done / blocks_total |
| VACUUM | `pg_stat_progress_vacuum` | heap_blks_vacuumed / heap_blks_total |
| CLUSTER / VACUUM FULL | `pg_stat_progress_cluster` | heap_blks_scanned / heap_blks_total |
| ANALYZE | `pg_stat_progress_analyze` | sample_blks_scanned / sample_blks_total |

### Operations without progress tracking (via `pg_stat_activity`)

| Operation | Available info |
|-----------|---------------|
| VALIDATE CONSTRAINT | query, state, duration, wait events |

These operations appear in snapshots with `progress_pct: nil`.

## Works great with

- **[online_migrations](https://github.com/fatkodima/online_migrations)** — use it to run `add_index_in_background`, then monitor progress with `pg_progress`
- **[strong_migrations](https://github.com/ankane/strong_migrations)** — catches unsafe migrations, pg_progress monitors the safe ones

## License

MIT
