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
        # Log the error
        puts "Error while pushing record to InfluxDB. #{e.class}: #{e.message}"

        unless queue.closed?
          # Put the record back into the queue
          queue << record

          # Wait a second before trying again
          sleep(1)
        end
      end
    end
  end
end
