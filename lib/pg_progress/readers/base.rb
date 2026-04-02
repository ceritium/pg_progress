module PgProgress
  module Readers
    class Base
      attr_reader :connection

      def initialize(connection:)
        @connection = connection
      end

      def read
        connection.select_all(sql).map { |row| build_entry(row) }
      end

      private

      def sql
        raise NotImplementedError
      end

      def build_entry(row)
        raise NotImplementedError
      end

      def percentage(done, total)
        total = total.to_i
        return nil if total.zero?

        (done.to_f / total * 100).round(2)
      end
    end
  end
end
