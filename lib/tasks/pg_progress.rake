namespace :pg_progress do
  desc "Show a snapshot of all in-progress PostgreSQL operations with phase detail"
  task status: :environment do
    run_status
  end

  namespace :status do
    databases = ActiveRecord::Tasks::DatabaseTasks.setup_initial_database_yaml
    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Show pg_progress status for #{name} database"
      task name => :environment do
        ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: name) do |pool|
          run_status(connection: pool.connection)
        end
      end
    end
  end

  desc "Watch PostgreSQL operations in real time with phase tracking"
  task :watch, [:interval] => :environment do |_, args|
    interval = (args[:interval] || 2).to_i
    puts "Watching PostgreSQL operations every #{interval}s... (Ctrl+C to stop)\n\n"
    PgProgress.watch(interval: interval)
  end

  namespace :watch do
    databases = ActiveRecord::Tasks::DatabaseTasks.setup_initial_database_yaml
    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Watch pg_progress for #{name} database"
      task name, [:interval] => :environment do |_, args|
        interval = (args[:interval] || 2).to_i
        puts "Watching #{name} database every #{interval}s... (Ctrl+C to stop)\n\n"
        ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: name) do |pool|
          PgProgress.watch(interval: interval, connection: pool.connection)
        end
      end
    end
  end

  def run_status(connection: ActiveRecord::Base.connection)
    snapshot = PgProgress.snapshot(connection: connection)

    if snapshot.empty?
      puts "No operations in progress."
      return
    end

    phases_map = PgProgress::Watcher::PHASES

    snapshot.entries.each_with_index do |entry, i|
      puts if i > 0

      label = entry.details[:index_name] || entry.table_name
      started = entry.started_at ? " — started #{entry.started_at.strftime("%H:%M:%S")}" : ""
      duration = entry.duration ? " (#{format_duration(entry.duration)})" : ""
      puts "#{entry.command} #{label} (PID #{entry.pid})#{started}#{duration}"

      all_phases = phases_map[entry.command]

      if all_phases
        current_index = all_phases.index(entry.phase)

        all_phases.each_with_index do |phase_name, idx|
          if current_index && idx < current_index
            puts "  \e[32m✓ #{phase_name}\e[0m"
          elsif phase_name == entry.phase
            progress = entry.progress_pct ? " [#{entry.progress_pct}%]" : ""
            puts "  \e[33m► #{phase_name}\e[0m#{progress}"
          else
            puts "  \e[90m  #{phase_name}\e[0m"
          end
        end
      else
        progress = entry.progress_pct ? " [#{entry.progress_pct}%]" : ""
        puts "  \e[33m► #{entry.phase}\e[0m#{progress}"
      end
    end
  end

  def format_duration(seconds)
    return "-" unless seconds

    seconds = seconds.to_f
    if seconds < 60 then "#{seconds.round(1)}s"
    elsif seconds < 3600 then "#{(seconds / 60).floor}m #{(seconds % 60).round(1)}s"
    else "#{(seconds / 3600).floor}h #{((seconds % 3600) / 60).floor}m"
    end
  end
end
