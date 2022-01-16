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
  attr_accessor :queue, :count, :push_thread

  def start
    self.queue = Queue.new
    self.count = 0

    loop do
      self.count += 1

      pull_from_senec
      push_to_influx

      break if max_count && count >= max_count

      sleep config.senec_interval
    end

    # Wait for the push thread (if there is one) to finish
    push_thread&.join
  end

  private

  # Pull data from SENEC and add to queue
  def pull_from_senec
    pull = SenecPull.new(config:, queue:)
    pull.run
    puts pull.success_message(count)
  rescue StandardError => e
    puts pull.failure_message(e)
  end

  # Push data from queue to InfluxDB
  # Do this in a separate thread so that the main thread is not blocked
  def push_to_influx
    # Do nothing if there is already a push thread running
    return if push_thread&.status

    # Create new thread and push to InfluxDB
    self.push_thread = Thread.new do
      push = InfluxPush.new(config:, queue:)
      push.run
      puts push.success_message
    rescue StandardError => e
      puts push.failure_message(e)
    end
  end
end
