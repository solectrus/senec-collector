require_relative 'flux_writer'

class InfluxPush
  def initialize(config:, queue:)
    @queue = queue
    @config = config
    @count = 0
  end

  attr_reader :config, :queue

  def run
    until queue.empty?
      record = queue.pop

      begin
        FluxWriter.push(config:, record:)
        @count += 1
      rescue StandardError
        # Put the record back into the queue
        queue << record

        raise
      end
    end
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
