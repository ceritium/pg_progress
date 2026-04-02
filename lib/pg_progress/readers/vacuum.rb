module PgProgress
  module Readers
    class Vacuum < Base
      private

      def sql
        <<~SQL
          SELECT
            pid, datname,
            relid::regclass::text AS table_name,
            phase,
            heap_blks_total, heap_blks_scanned, heap_blks_vacuumed,
            index_vacuum_count, max_dead_tuples, num_dead_tuples
          FROM pg_stat_progress_vacuum
        SQL
      end

      def build_entry(row)
        Entry.new(
          pid: row["pid"].to_i,
          datname: row["datname"],
          table_name: row["table_name"],
          command: "VACUUM",
          phase: row["phase"],
          progress_pct: percentage(row["heap_blks_vacuumed"], row["heap_blks_total"]),
          started_at: nil,
          duration: nil,
          details: {
            heap_blks_total: row["heap_blks_total"].to_i,
            heap_blks_scanned: row["heap_blks_scanned"].to_i,
            heap_blks_vacuumed: row["heap_blks_vacuumed"].to_i,
            index_vacuum_count: row["index_vacuum_count"].to_i,
            max_dead_tuples: row["max_dead_tuples"].to_i,
            num_dead_tuples: row["num_dead_tuples"].to_i
          }
        )
      end
    end
  end
end
