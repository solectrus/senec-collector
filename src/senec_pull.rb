require 'senec'
require_relative 'solectrus_record'

class SenecPull
  def initialize(config:, queue:)
    @queue = queue
    @config = config
  end

  attr_reader :config, :queue

  def run
    data = Senec::Request.new host: config.senec_host
    @record = SolectrusRecord.new(data)
    return unless @record.valid?

    queue << @record
  end

  def success_message(count)
    return unless @record

    "\nGot record ##{count} from SENEC at #{config.senec_host}: " \
      "Inverter #{@record.inverter_power} W, House #{@record.house_power} W, #{Time.at(@record.measure_time)}"
  end

  def failure_message(error)
    "Error getting record from SENEC at #{config.senec_host}: #{error}"
  end
end
