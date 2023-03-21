require_relative 'influx_push'
require_relative 'senec_pull'

class Loop
  def self.start(config:, max_count: nil)
    new(config:, max_count:).start
  end

  def initialize(config:, max_count:)
    @config = config
    @max_count = max_count
  end

  attr_reader :config, :max_count
  attr_accessor :queue

  def start
    self.queue = Queue.new

    pull_thread = Thread.new { pull_loop }
    push_thread = Thread.new { push_loop }

    # Wait for the pull thread to finish (will happen if max_count is set)
    pull_thread.join

    # Push any remaining records to InfluxDB
    close_queue

    # Wait for the push thread to finish (will happen because queue is closed)
    push_thread.join
  rescue SystemExit, Interrupt
    puts 'Exiting...'

    # Stop pulling data from SENEC
    pull_thread.exit

    # Push any remaining records to InfluxDB (can take a while)
    close_queue

    # Stop pushing data to InfluxDB
    push_thread.exit
  end

  private

  # Pull data from SENEC and add to queue
  def pull_loop
    pull = SenecPull.new(config:, queue:)

    loop do
      begin
        pull.next
        puts pull.success_message
      rescue StandardError => e
        puts pull.failure_message(e)
      end

      break if max_count && pull.count >= max_count

      sleep config.senec_interval
    end
  end

  # Push data from queue to InfluxDB
  def push_loop
    InfluxPush.new(config:, queue:).run
  end

  def close_queue
    until queue.empty?
      puts "Waiting for #{queue.size} records to be pushed to InfluxDB"
      sleep 1
    end

    queue.close
  end
end
