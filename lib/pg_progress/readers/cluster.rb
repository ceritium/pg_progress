module PgProgress
  module Readers
    class Cluster < Base
      private

      def sql
        <<~SQL
          SELECT
            pid, datname,
            relid::regclass::text AS table_name,
            command, phase,
            cluster_index_relid::regclass::text AS index_name,
            heap_tuples_scanned, heap_tuples_written,
            heap_blks_total, heap_blks_scanned,
            index_rebuild_count
          FROM pg_stat_progress_cluster
        SQL
      end

      def build_entry(row)
        Entry.new(
          pid: row["pid"].to_i,
          datname: row["datname"],
          table_name: row["table_name"],
          command: row["command"],
          phase: row["phase"],
          progress_pct: percentage(row["heap_blks_scanned"], row["heap_blks_total"]),
          started_at: nil,
          duration: nil,
          details: {
            index_name: row["index_name"],
            heap_tuples_scanned: row["heap_tuples_scanned"].to_i,
            heap_tuples_written: row["heap_tuples_written"].to_i,
            heap_blks_total: row["heap_blks_total"].to_i,
            heap_blks_scanned: row["heap_blks_scanned"].to_i,
            index_rebuild_count: row["index_rebuild_count"].to_i
          }
        )
      end
    end
  end
end
