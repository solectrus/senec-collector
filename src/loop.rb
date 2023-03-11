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

    # Wait for the threads to finish
    push_thread.join
    pull_thread.join
  end

  private

  # Pull data from SENEC and add to queue
  def pull_loop
    pull = SenecPull.new(config:, queue:)
    count = 0

    loop do
      count += 1

      begin
        pull.run
        puts pull.success_message(count)
      rescue StandardError => e
        puts pull.failure_message(e)
      end

      break if max_count && count >= max_count

      sleep config.senec_interval
    end
  end

  # Push data from queue to InfluxDB
  def push_loop
    push = InfluxPush.new(config:, queue:)
    count = 0

    loop do
      begin
        count += push.run

        puts push.success_message if push.success_message
      rescue StandardError => e
        puts push.failure_message(e)
      end

      break if max_count && count >= max_count

      sleep 1
    end
  end
end
