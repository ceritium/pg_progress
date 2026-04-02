module PgProgress
  module Readers
    class Analyze < Base
      private

      def sql
        <<~SQL
          SELECT
            pid, datname,
            relid::regclass::text AS table_name,
            phase,
            sample_blks_total, sample_blks_scanned,
            ext_stats_total, ext_stats_computed,
            child_tables_total, child_tables_done,
            current_child_table_relid::regclass::text AS current_child_table
          FROM pg_stat_progress_analyze
        SQL
      end

      def build_entry(row)
        Entry.new(
          pid: row["pid"].to_i,
          datname: row["datname"],
          table_name: row["table_name"],
          command: "ANALYZE",
          phase: row["phase"],
          progress_pct: percentage(row["sample_blks_scanned"], row["sample_blks_total"]),
          started_at: nil,
          duration: nil,
          details: {
            sample_blks_total: row["sample_blks_total"].to_i,
            sample_blks_scanned: row["sample_blks_scanned"].to_i,
            ext_stats_total: row["ext_stats_total"].to_i,
            ext_stats_computed: row["ext_stats_computed"].to_i,
            child_tables_total: row["child_tables_total"].to_i,
            child_tables_done: row["child_tables_done"].to_i,
            current_child_table: row["current_child_table"]
          }
        )
      end
    end
  end
end
