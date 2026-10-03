require 'buffer_store'
require 'influx_push'
require 'senec_pull'
require 'forwardable'

class Loop
  extend Forwardable

  def_delegators :config, :logger

  def self.start(config:, max_count: nil, max_wait: 6, &)
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

    # Restore records buffered before the last shutdown
    restore_buffer

    # Start pulling even if InfluxDB is not ready (e.g. internet outage).
    # Records are buffered in the queue and pushed as soon as InfluxDB is available.
    wait_for_influx(max_wait)

    pull_thread = Thread.new { pull_loop }
    push_thread = Thread.new { push_loop }

    # Wait for the pull thread to finish (will happen if max_count is set)
    pull_thread.join

    # Push any remaining records to InfluxDB
    close_queue

    # Wait for the push thread to finish (will happen because queue is closed)
    push_thread.join
  rescue SystemExit, SignalException # SignalException covers SIGTERM (docker stop) and SIGINT
    shutdown(pull_thread, push_thread)
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

  def wait_for_influx(max_wait)
    logger.info 'Wait until InfluxDB is ready ...', newline: false

    count = 0
    until (ready = influx_push.ready?) || (max_wait && count >= max_wait)
      logger.info '.', newline: false
      count += 1
      sleep 5
    end

    if ready
      logger.info ' OK'
    else
      logger.error "\nInfluxDB not ready after #{count * 5} seconds, records will be buffered until it is available"
      influx_push.mark_unavailable
    end
    logger.info ''
  end

  # Push data from queue to InfluxDB
  def push_loop
    influx_push.run
  end

  def influx_push
    @influx_push ||= InfluxPush.new(config:, queue:)
  end

  def buffer_store
    @buffer_store ||= BufferStore.new(logger:)
  end

  # Threads are nil if the signal arrives while waiting for InfluxDB
  def shutdown(pull_thread, push_thread)
    logger.error 'Exiting...'

    # Stop pulling data from SENEC
    pull_thread&.exit

    # Stop pushing data to InfluxDB
    push_thread&.exit
    push_thread&.join

    # Save the records that could not be pushed
    save_buffer
  end

  def restore_buffer
    buffer_store.load.each { |record| queue << record }
  end

  def save_buffer
    records = influx_push.pending_records
    records << queue.pop until queue.empty?

    # Records can be in both places if the thread was killed while waiting to retry
    buffer_store.save(records.uniq)
  end

  def close_queue
    until queue.empty?
      logger.info "Waiting for #{queue.size} records to be pushed to InfluxDB"
      sleep 1
    end

    queue.close
  end
end
