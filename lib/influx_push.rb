require 'flux_writer'
require 'forwardable'

class InfluxPush
  extend Forwardable
  def_delegators :config, :logger

  def initialize(config:, queue:)
    @config = config
    @queue = queue
    @flux_writer = FluxWriter.new(config)
  end

  attr_reader :config, :queue, :flux_writer

  def run
    until queue.closed?
      # Wait for a record to be added to the queue
      record = queue.pop

      # Push (unless queue has been closed)
      push(record) if record
    end
  end

  private

  def push(record)
    flux_writer.push(record)
    logger.info "Successfully pushed record ##{record.id} to InfluxDB"
  rescue StandardError => e
    error_handling(record, e)

    # Wait a bit before trying again
    sleep(5)
  end

  def error_handling(record, error)
    # Log the error
    logger.error "Error while pushing record ##{record.id} to InfluxDB: #{error.message}"

    return if queue.closed?

    # Put the record back into the queue
    queue << record

    logger.info "The record has been queued. Will retry to push #{queue.size} records later."
  end
end
