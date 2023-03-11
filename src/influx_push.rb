require_relative 'flux_writer'

class InfluxPush
  def initialize(config:, queue:)
    @config = config
    @queue = queue
    @flux_writer = FluxWriter.new(config)
  end

  attr_reader :config, :queue, :flux_writer

  def run
    @count = 0

    until queue.empty?
      record = queue.pop

      begin
        flux_writer.push(record)
        @count += 1
      rescue StandardError
        # Put the record back into the queue
        queue << record

        raise
      end
    end

    @count
  end

  def success_message
    return unless @count.positive?

    "Successfully pushed #{pluralize(@count, 'record', 'records')} to InfluxDB"
  end

  def failure_message(error)
    "Error while pushing #{pluralize(queue.length, 'record', 'records')} to InfluxDB. #{error.class}: #{error.message}"
  end

  private

  def pluralize(count, singular, plural)
    count == 1 ? singular : "#{count} #{plural}"
  end
end
