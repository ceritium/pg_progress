module PgProgress
  class Snapshot
    READERS = {
      create_index: Readers::CreateIndex,
      vacuum: Readers::Vacuum,
      cluster: Readers::Cluster,
      analyze: Readers::Analyze,
      activity: Readers::Activity
    }.freeze

    attr_reader :entries, :captured_at

    def self.capture(connection: ActiveRecord::Base.connection)
      entries = READERS.flat_map { |_, klass| klass.new(connection: connection).read }
      enrich_with_duration(entries, connection)
      new(entries: entries)
    end

    def self.enrich_with_duration(entries, connection)
      pids = entries.map(&:pid).uniq
      return if pids.empty?

      rows = connection.select_all(<<~SQL)
        SELECT pid, query_start,
               EXTRACT(EPOCH FROM (clock_timestamp() - query_start)) AS duration_seconds
        FROM pg_stat_activity
        WHERE pid IN (#{pids.join(", ")})
      SQL

      durations = rows.each_with_object({}) do |row, hash|
        hash[row["pid"].to_i] = {
          duration: row["duration_seconds"]&.to_f&.round(1),
          started_at: row["query_start"]
        }
      end

      entries.map! do |entry|
        info = durations[entry.pid]
        next entry unless info

        updates = {}
        updates[:duration] = info[:duration] if entry.duration.nil?
        updates[:started_at] = info[:started_at] if entry.started_at.nil?
        updates.empty? ? entry : Entry.new(**entry.to_h.merge(updates))
      end
    end
    private_class_method :enrich_with_duration

    def initialize(entries:)
      @entries = entries
      @captured_at = Time.current
    end

    def for_table(table_name)
      entries.select { |e| e.table_name == table_name.to_s }
    end

    def for_pid(pid)
      entries.find { |e| e.pid == pid.to_i }
    end

    def empty?
      entries.empty?
    end

    def to_a
      entries
    end
  end
end
