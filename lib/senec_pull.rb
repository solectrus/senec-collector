class SenecPull
  # Maximum number of records to buffer while InfluxDB is not reachable.
  # One record needs about 1 KB of memory, so the buffer is limited to about 100 MB.
  # With the minimum interval of 5 seconds this covers more than 5 days.
  MAX_QUEUE_SIZE = 100_000

  def initialize(config:, queue:)
    @queue = queue
    @config = config
    @count = 0
  end

  attr_reader :config, :queue, :count

  def next
    record = config.adapter.solectrus_record(@count += 1)
    return unless record

    make_room
    queue << record

    record
  end

  private

  # Drop the oldest record if the buffer is full
  def make_room
    @buffer_full = false if queue.empty?
    return if queue.size < MAX_QUEUE_SIZE

    queue.pop(true)
    return if @buffer_full

    # Log once per outage only
    @buffer_full = true
    config.logger.error "Buffer is full (#{MAX_QUEUE_SIZE} records), dropping oldest records"
  rescue ThreadError
    # Queue has been emptied by the push thread in the meantime
  end
end
