module PgProgress
  module Readers
    class Activity < Base
      MAINTENANCE_PATTERNS = [
        "VALIDATE CONSTRAINT",
        "VALIDATE FOREIGN KEY"
      ].freeze

      private

      def sql
        <<~SQL
          SELECT
            pid, datname, query, state, wait_event_type, wait_event,
            EXTRACT(EPOCH FROM (clock_timestamp() - query_start)) AS duration_seconds
          FROM pg_stat_activity
          WHERE state = 'active'
            AND pid != pg_backend_pid()
            AND (#{MAINTENANCE_PATTERNS.map { |p| "query ILIKE #{connection.quote("%#{p}%")}" }.join(" OR ")})
            AND query_start < clock_timestamp() - interval '1 second'
        SQL
      end

      def build_entry(row)
        Entry.new(
          pid: row["pid"].to_i,
          datname: row["datname"],
          table_name: extract_table_name(row["query"]),
          command: extract_command(row["query"]),
          phase: row["wait_event"] ? "waiting: #{row["wait_event"]}" : row["state"],
          progress_pct: nil,
          started_at: nil,
          duration: row["duration_seconds"]&.to_f&.round(1),
          details: {
            query: row["query"],
            state: row["state"],
            wait_event_type: row["wait_event_type"],
            wait_event: row["wait_event"]
          }
        )
      end

      def extract_table_name(query)
        match = query&.match(/ALTER\s+TABLE\s+(?:ONLY\s+)?(\S+)/i)
        match ? match[1].tr('"', "") : nil
      end

      def extract_command(query)
        if query&.match?(/VALIDATE\s+CONSTRAINT/i)
          "VALIDATE CONSTRAINT"
        else
          "MAINTENANCE"
        end
      end
    end
  end
end
