require 'oj'
require 'senec'
require_relative 'solectrus_record'

Oj.mimic_JSON

class SenecPull
  def initialize(config:, queue:)
    @queue = queue
    @config = config
  end

  attr_reader :config, :queue

  def run
    data =
      Senec::Request.new host: config.senec_host,
                         state_names: config.senec_state_names
    @record = SolectrusRecord.new(data)
    return unless @record.valid?

    queue << @record
  end

  def success_message(count)
    return unless @record

    "\nGot record ##{count} from SENEC at #{config.senec_host}: " \
      "#{@record.current_state}, " \
      "Inverter #{@record.inverter_power} W, House #{@record.house_power} W, " \
      "#{Time.at(@record.measure_time)}"
  end

  def failure_message(error)
    "Error getting data from SENEC at #{config.senec_host}: #{error}"
  end
end
