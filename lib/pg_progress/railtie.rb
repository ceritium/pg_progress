module PgProgress
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/pg_progress.rake"
    end
  end
end
