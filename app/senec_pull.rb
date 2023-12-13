require 'oj'
require 'senec'
require_relative 'solectrus_record'
require_relative 'senec_state_names'

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
      Senec::Local::Request.new connection: config.senec_connection,
                                state_names: senec_state_names
    return unless data.measure_time

    record = SolectrusRecord.new(@count += 1, data)
    queue << record

    record
  end

  def senec_state_names
    @senec_state_names ||= SenecStateNames.new(config:).fetch
  end
end
