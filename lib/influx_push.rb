require 'flux_writer'
require 'forwardable'

class InfluxPush
  extend Forwardable

  # Maximum number of records to push in one request
  BATCH_SIZE = 1000

  # HTTP status codes for data that InfluxDB will never accept (e.g. field type conflict).
  # Retrying such records would block all other records.
  REJECTED_CODES = %w[400 422].freeze

  def_delegators :config, :logger

  def initialize(config:, queue:)
    @config = config
    @queue = queue
    @flux_writer = FluxWriter.new(config)
  end

  attr_reader :config, :queue, :flux_writer

  def ready?
    flux_writer.ready?
  end

  # Avoid logging the first failed push if InfluxDB is already known to be unavailable
  def mark_unavailable
    @failing_since = Time.now
  end

  # Records taken from the queue, but not pushed yet.
  # They are lost if the thread is killed during a push, so the caller must save them.
  def pending_records
    @pending.to_a
  end

  def run
    until queue.closed?
      # Defer Thread#exit until the next blocking call (waiting for the queue),
      # so records taken from the queue are always tracked as pending
      Thread.handle_interrupt(Object => :on_blocking) { @pending = next_batch }

      # Push (unless queue has been closed)
      push(@pending) if @pending.any?
      @pending = []
    end
  end

  private

  def next_batch
    # Wait for a record to be added to the queue (nil if the queue has been closed)
    record = queue.pop
    return [] unless record

    # Add more records if available (e.g. buffered during an outage)
    records = [record]
    while records.size < BATCH_SIZE && (record = queue.pop(timeout: 0))
      records << record
    end
    records
  end

  def push(records)
    flux_writer.push(records)
    logger.info "Successfully pushed #{description(records)} to InfluxDB"
    log_recovery if @failing_since
  rescue StandardError => e
    if rejected_by_influx?(e)
      drop_rejected(records, e)
    else
      retry_later(records, e)
    end
  end

  def rejected_by_influx?(error)
    error.is_a?(InfluxDB2::InfluxError) && REJECTED_CODES.include?(error.code.to_s)
  end

  # Push the records one by one to drop the rejected ones only
  def drop_rejected(records, error)
    if records.one?
      logger.error "InfluxDB rejected record ##{records.first.id}, dropping it: #{error.message}"
    else
      records.each { |record| push([record]) }
    end
  end

  def retry_later(records, error)
    # Log the first failure only, so a long outage does not flood the log
    unless @failing_since
      @failing_since = Time.now
      logger.error "Error while pushing #{description(records)} to InfluxDB: #{error.message}"
      logger.error 'Records will be buffered and pushed when InfluxDB is available again.'
    end

    return if queue.closed?

    # Put the records back into the queue
    records.each { |record| queue << record }

    # Wait a bit before trying again
    sleep(5)
  end

  def description(records)
    records.one? ? "record ##{records.first.id}" : "#{records.size} records"
  end

  def log_recovery
    logger.info "InfluxDB is available again after #{(Time.now - @failing_since).round} seconds, " \
                "#{queue.size} buffered records remaining"
    @failing_since = nil
  end
end
