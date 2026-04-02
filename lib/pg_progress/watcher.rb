module PgProgress
  class Watcher
    PHASES = {
      "CREATE INDEX" => [
        "initializing",
        "building index: scanning table",
        "building index: sorting live tuples",
        "building index: loading tuples in tree"
      ],
      "CREATE INDEX CONCURRENTLY" => [
        "initializing",
        "waiting for writers before build",
        "building index: scanning table",
        "building index: sorting live tuples",
        "building index: loading tuples in tree",
        "waiting for writers before validation",
        "index validation: scanning index",
        "index validation: sorting tuples",
        "index validation: scanning table",
        "waiting for old snapshots",
        "waiting for readers before marking dead",
        "waiting for readers before dropping"
      ],
      "REINDEX" => [
        "initializing",
        "building index: scanning table",
        "building index: sorting live tuples",
        "building index: loading tuples in tree"
      ],
      "REINDEX CONCURRENTLY" => [
        "initializing",
        "waiting for writers before build",
        "building index: scanning table",
        "building index: sorting live tuples",
        "building index: loading tuples in tree",
        "waiting for writers before validation",
        "index validation: scanning index",
        "index validation: sorting tuples",
        "index validation: scanning table",
        "waiting for old snapshots",
        "waiting for readers before marking dead",
        "waiting for readers before dropping"
      ],
      "VACUUM" => [
        "initializing",
        "scanning heap",
        "vacuuming indexes",
        "vacuuming heap",
        "cleaning up indexes",
        "truncating heap",
        "performing final cleanup"
      ],
      "VACUUM FULL" => [
        "initializing",
        "seq scanning heap",
        "index scanning heap",
        "sorting tuples",
        "writing new heap",
        "swapping relation files",
        "rebuilding index",
        "performing final cleanup"
      ],
      "CLUSTER" => [
        "initializing",
        "seq scanning heap",
        "index scanning heap",
        "sorting tuples",
        "writing new heap",
        "swapping relation files",
        "rebuilding index",
        "performing final cleanup"
      ],
      "ANALYZE" => [
        "initializing",
        "acquiring sample rows",
        "acquiring inherited sample rows",
        "computing statistics",
        "computing extended statistics",
        "finalizing analyze"
      ]
    }.freeze

    Event = Data.define(:type, :entry, :previous_phase, :phase_duration)

    attr_reader :interval, :connection

    def initialize(interval: 2, connection: ActiveRecord::Base.connection)
      @interval = interval
      @connection = connection
      @tracking = {} # pid => { command:, table_name:, phases: [{ phase:, started_at: }] }
    end

    def run(&block)
      loop do
        snapshot = Snapshot.capture(connection: connection)
        events = process_snapshot(snapshot)

        if block
          events.each { |event| block.call(event) }
        else
          render(snapshot)
        end

        sleep interval
      rescue Interrupt
        break
      end
    end

    private

    def process_snapshot(snapshot)
      events = []
      seen_pids = Set.new

      snapshot.entries.each do |entry|
        seen_pids.add(entry.pid)
        tracked = @tracking[entry.pid]

        if tracked.nil?
          @tracking[entry.pid] = new_tracking(entry)
          event = Event.new(type: :started, entry: entry, previous_phase: nil, phase_duration: nil)
          events << event
          log_started(entry)
        elsif tracked[:phases].last[:phase] != entry.phase
          phase_duration = Time.current - tracked[:phases].last[:started_at]
          previous_phase = tracked[:phases].last[:phase]
          tracked[:phases].last[:duration] = phase_duration
          tracked[:phases] << { phase: entry.phase, started_at: Time.current, duration: nil }
          event = Event.new(type: :phase_change, entry: entry, previous_phase: previous_phase, phase_duration: phase_duration)
          events << event
          log_phase_change(entry, previous_phase, phase_duration)
        end
      end

      completed_pids = @tracking.keys - seen_pids.to_a
      completed_pids.each do |pid|
        tracked = @tracking.delete(pid)
        next unless tracked

        phase_duration = Time.current - tracked[:phases].last[:started_at]
        tracked[:phases].last[:duration] = phase_duration
        dummy_entry = Entry.new(
          pid: pid, datname: nil, table_name: tracked[:table_name],
          command: tracked[:command], phase: "completed",
          progress_pct: 100.0, duration: nil, details: {}
        )
        event = Event.new(type: :completed, entry: dummy_entry, previous_phase: tracked[:phases].last[:phase], phase_duration: phase_duration)
        events << event
        log_completed(tracked, phase_duration)
      end

      events
    end

    def new_tracking(entry)
      { command: entry.command, table_name: entry.table_name,
        phases: [{ phase: entry.phase, started_at: Time.current, duration: nil }] }
    end

    def render(snapshot)
      system("clear") || system("cls")

      if snapshot.empty?
        puts "No operations in progress. Watching... (Ctrl+C to stop)"
        return
      end

      snapshot.entries.each do |entry|
        tracked = @tracking[entry.pid]
        render_operation(entry, tracked)
        puts
      end
    end

    def render_operation(entry, tracked)
      label = entry.details[:index_name] || entry.table_name
      puts "#{entry.command} #{label} (PID #{entry.pid})"

      all_phases = PHASES[entry.command]

      if all_phases && tracked
        completed_phase_names = tracked[:phases][..-2]&.map { |p| p[:phase] } || []

        all_phases.each do |phase_name|
          completed_info = tracked[:phases].find { |p| p[:phase] == phase_name }

          if phase_name == entry.phase
            progress = entry.progress_pct ? " [#{entry.progress_pct}%]" : ""
            elapsed = tracked[:phases].last[:started_at] ? format_duration(Time.current - tracked[:phases].last[:started_at]) : ""
            puts "  \e[33m► #{phase_name}\e[0m#{" " * [1, 50 - phase_name.length].max}#{elapsed}#{progress}"
          elsif completed_phase_names.include?(phase_name) && completed_info&.dig(:duration)
            puts "  \e[32m✓ #{phase_name}\e[0m#{" " * [1, 50 - phase_name.length].max}#{format_duration(completed_info[:duration])}"
          elsif completed_phase_names.include?(phase_name)
            puts "  \e[32m✓ #{phase_name}\e[0m"
          else
            puts "  \e[90m  #{phase_name}\e[0m"
          end
        end
      else
        progress = entry.progress_pct ? " [#{entry.progress_pct}%]" : ""
        duration = entry.duration ? " #{format_duration(entry.duration)}" : ""
        puts "  \e[33m► #{entry.phase}\e[0m#{duration}#{progress}"
      end
    end

    def log_started(entry)
      label = entry.details[:index_name] || entry.table_name
      logger&.info("[PgProgress] #{entry.command} #{label} (PID #{entry.pid}) started — phase: #{entry.phase}")
    end

    def log_phase_change(entry, previous_phase, phase_duration)
      label = entry.details[:index_name] || entry.table_name
      logger&.info("[PgProgress] #{entry.command} #{label} (PID #{entry.pid}) phase: #{previous_phase} -> #{entry.phase} (#{format_duration(phase_duration)})")
    end

    def log_completed(tracked, last_phase_duration)
      logger&.info("[PgProgress] #{tracked[:command]} #{tracked[:table_name]} completed — last phase: #{tracked[:phases].last[:phase]} (#{format_duration(last_phase_duration)})")
    end

    def format_duration(seconds)
      return "-" unless seconds

      seconds = seconds.to_f
      if seconds < 60
        "#{seconds.round(1)}s"
      elsif seconds < 3600
        "#{(seconds / 60).floor}m #{(seconds % 60).round(1)}s"
      else
        "#{(seconds / 3600).floor}h #{((seconds % 3600) / 60).floor}m"
      end
    end

    def logger
      defined?(Rails) ? Rails.logger : nil
    end
  end
end
