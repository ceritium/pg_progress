module PgProgress
  module Readers
    class CreateIndex < Base
      private

      def sql
        <<~SQL
          SELECT
            pid, datname,
            relid::regclass::text AS table_name,
            index_relid::regclass::text AS index_name,
            command, phase,
            lockers_total, lockers_done, current_locker_pid,
            blocks_total, blocks_done,
            tuples_total, tuples_done,
            partitions_total, partitions_done
          FROM pg_stat_progress_create_index
        SQL
      end

      def build_entry(row)
        Entry.new(
          pid: row["pid"].to_i,
          datname: row["datname"],
          table_name: row["table_name"],
          command: row["command"],
          phase: row["phase"],
          progress_pct: percentage(row["blocks_done"], row["blocks_total"]),
          started_at: nil,
          duration: nil,
          details: {
            index_name: row["index_name"],
            blocks_total: row["blocks_total"].to_i,
            blocks_done: row["blocks_done"].to_i,
            tuples_total: row["tuples_total"].to_i,
            tuples_done: row["tuples_done"].to_i,
            lockers_total: row["lockers_total"].to_i,
            lockers_done: row["lockers_done"].to_i,
            partitions_total: row["partitions_total"].to_i,
            partitions_done: row["partitions_done"].to_i
          }
        )
      end
    end
  end
end
