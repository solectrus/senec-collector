require 'oj'
require 'senec'
require_relative 'solectrus_record'

Oj.mimic_JSON

class SenecPull
  def initialize(config:, queue:)
    @queue = queue
    @config = config
    @count = 0
  end

  attr_reader :config, :queue, :count

  def next
    data =
      Senec::Request.new host: config.senec_host,
                         state_names: config.senec_state_names
    return unless data.measure_time

    @record = SolectrusRecord.new(@count += 1, data)
    queue << @record
  end

  def success_message
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
