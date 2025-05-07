require 'influx_push'
require 'senec_pull'
require 'forwardable'

class Loop
  extend Forwardable
  def_delegators :config, :logger

  def self.start(config:, max_count: nil, max_wait: 12, &)
    new(config:, max_count:, max_wait:, &).start
  end

  def initialize(config:, max_count:, max_wait:)
    @config = config
    @max_count = max_count
    @max_wait = max_wait
  end

  attr_reader :config, :max_count, :max_wait
  attr_accessor :queue

  def start
    self.queue = Queue.new

    return unless influx_ready?(max_wait)

    pull_thread = Thread.new { pull_loop }
    push_thread = Thread.new { push_loop }

    # Wait for the pull thread to finish (will happen if max_count is set)
    pull_thread.join

    # Push any remaining records to InfluxDB
    close_queue

    # Wait for the push thread to finish (will happen because queue is closed)
    push_thread.join
  rescue SystemExit, Interrupt
    logger.error 'Exiting...'

    # Stop pulling data from SENEC
    pull_thread.exit

    # Push any remaining records to InfluxDB (can take a while)
    close_queue

    # Stop pushing data to InfluxDB
    push_thread.exit
  end

  private

  def senec_pull
    @senec_pull ||= SenecPull.new(config:, queue:)
  end

  # Pull data from SENEC and add to queue
  def pull_loop
    loop do
      senec_pull.next

      break if max_count && senec_pull.count >= max_count

      sleep config.senec_interval
    end
  end

  def influx_ready?(max_wait)
    logger.info 'Wait until InfluxDB is ready ...', newline: false

    count = 0
    until (ready = influx_push.ready?) || (max_wait && count >= max_wait)
      logger.info '.', newline: false
      count += 1
      sleep 5
    end

    if ready
      logger.info ' OK'
      logger.info ''
      true
    else
      logger.error "\nInfluxDB not ready after #{count * 5} seconds - aborting."
      false
    end
  end

  # Push data from queue to InfluxDB
  def push_loop
    influx_push.run
  end

  def influx_push
    @influx_push ||= InfluxPush.new(config:, queue:)
  end

  def close_queue
    until queue.empty?
      logger.info "Waiting for #{queue.size} records to be pushed to InfluxDB"
      sleep 1
    end

    queue.close
  end
end
