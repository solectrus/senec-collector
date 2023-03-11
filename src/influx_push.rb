require_relative 'flux_writer'

class InfluxPush
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
      return unless record

      begin
        flux_writer.push(record)
        puts 'Successfully pushed record to InfluxDB'
      rescue StandardError => e
        error_handling(record, e)

        # Wait a second before trying again
        sleep(1)
      end
    end
  end

  private

  def error_handling(record, error)
    # Log the error
    puts "Error while pushing record to InfluxDB: #{error.message}"

    return if queue.closed?

    # Put the record back into the queue
    queue << record

    puts "The record has been queued. Will retry to push #{queue.size} records later."
  end
end
