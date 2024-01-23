require 'flux_writer'

class InfluxPush
  def initialize(config:, queue:, &message_handler)
    @config = config
    @queue = queue
    @flux_writer = FluxWriter.new(config)
    @message_handler = message_handler
  end

  attr_reader :config, :queue, :flux_writer, :message_handler

  def run
    until queue.closed?
      # Wait for a record to be added to the queue
      record = queue.pop

      # Stop if the queue has been closed
      next unless record

      begin
        flux_writer.push(record)
        send_message "Successfully pushed record ##{record.id} to InfluxDB"
      rescue StandardError => e
        error_handling(record, e)

        # Wait a bit before trying again
        sleep(5)
      end
    end
  end

  private

  def error_handling(record, error)
    # Log the error
    send_message "Error while pushing record ##{record.id} to InfluxDB: #{error.message}"

    return if queue.closed?

    # Put the record back into the queue
    queue << record

    send_message "The record has been queued. Will retry to push #{queue.size} records later."
  end

  def send_message(message)
    message_handler&.call(message)
  end
end
