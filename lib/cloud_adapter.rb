require 'solectrus_record'
require 'forwardable'

class CloudAdapter
  extend Forwardable
  def_delegators :config, :logger

  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def init_message
    "Pulling from SENEC cloud every #{config.senec_interval} seconds"
  end

  def connection
    @connection ||=
      Senec::Cloud::Connection.new(username: config.senec_username, password: config.senec_password)
  end

  def solectrus_record(id = 1)
    # Reset data cache
    @data = nil

    SolectrusRecord.new(id, record_hash).tap do |record|
      logger.info success_message(record)
    end
  rescue StandardError => e
    logger.error failure_message(e)
    nil
  end

  private

  def record_hash
    { measure_time:,
      inverter_power:,
      house_power:,
      grid_power_minus:,
      grid_power_plus:,
      bat_power_minus:,
      bat_power_plus:,
      bat_fuel_charge:,
      wallbox_charge_power:, }
  end

  def data
    @data ||= Senec::Cloud::Dashboard[connection].first.data
  end

  def success_message(record)
    "\nGot record ##{record.id} at " \
      "#{Time.at(record.measure_time)} " \
      "Inverter #{record.inverter_power} W, House #{record.house_power} W, " \
      "Grid -#{record.grid_power_minus} W / +#{record.grid_power_plus} W, " \
      "Bat -#{record.bat_power_minus} W / +#{record.bat_power_plus} W, #{record.bat_fuel_charge} %, " \
      "Wallbox #{record.wallbox_charge_power} W"
  end

  def failure_message(error)
    "Error getting data from SENEC cloud: #{error}"
  end

  def measure_time
    Time.parse(data['zeitstempel']).to_i
  end

  def inverter_power
    data.dig('aktuell', 'stromerzeugung', 'wert').round
  end

  def house_power
    data.dig('aktuell', 'stromverbrauch', 'wert').round
  end

  def wallbox_charge_power
    data.dig('aktuell', 'wallbox', 'wert').round
  end

  def grid_power_minus
    data.dig('aktuell', 'netzeinspeisung', 'wert').round
  end

  def grid_power_plus
    data.dig('aktuell', 'netzbezug', 'wert').round
  end

  def bat_power_plus
    data.dig('aktuell', 'speicherbeladung', 'wert').round
  end

  def bat_power_minus
    data.dig('aktuell', 'speicherentnahme', 'wert').round
  end

  def bat_fuel_charge
    data.dig('aktuell', 'speicherfuellstand', 'wert').round(1)
  end
end
