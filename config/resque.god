rails_env   = ENV['RAILS_ENV']  || "production"
num_workers = rails_env == 'production' ? 5 : 2

num_workers.times do |num|
  God.watch do |w|
    w.dir      = '/data/apps/checkafilm/current'
    w.name     = "checkafilm-resque-#{num}"
    w.group    = 'checkafilm-resque'
    w.interval = 30.seconds
    w.env      = {'QUEUE'=>'*', 'RAILS_ENV'=>'production', 'RAILS_ROOT' => '/data/apps/checkafilm/current'}
    w.start    = 'QUEUE=* RAILS_ENV=production bundle exec rake environment resque:work'
    w.log      = '/data/apps/checkafilm/current/log/resque.log'

    w.uid = 'www-data'
    w.gid = 'www-data'

    # restart if memory gets too high
    w.transition(:up, :restart) do |on|
      on.condition(:memory_usage) do |c|
        c.above = 350.megabytes
        c.times = 2
      end
    end

    # determine the state on startup
    w.transition(:init, { true => :up, false => :start }) do |on|
      on.condition(:process_running) do |c|
        c.running = true
      end
    end

    # determine when process has finished starting
    w.transition([:start, :restart], :up) do |on|
      on.condition(:process_running) do |c|
        c.running = true
        c.interval = 5.seconds
      end

      # failsafe
      on.condition(:tries) do |c|
        c.times = 5
        c.transition = :start
        c.interval = 5.seconds
      end
    end

    # start if process is not running
    w.transition(:up, :start) do |on|
      on.condition(:process_running) do |c|
        c.running = false
      end
    end
  end
end
