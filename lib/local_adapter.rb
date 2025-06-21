require 'solectrus_record'
require 'forwardable'

class LocalAdapter
  extend Forwardable
  def_delegators :config, :logger

  def initialize(config:)
    @config = config

    logger.info "Pulling from your local SENEC at #{config.senec_url} every #{config.senec_interval} seconds"
  end

  attr_reader :config

  def connection
    @connection ||=
      Senec::Local::Connection.new(host: config.senec_host, schema: config.senec_schema)
  end

  def state_names
    @state_names ||= begin
      logger.info "Getting state names (language: #{config.senec_language}) from SENEC by parsing source code..."

      names =
        Senec::Local::State.new(connection:).names(
          language: config.senec_language,
        )
      logger.info "OK, got #{names.length} state names"
      names
    rescue StandardError => e
      logger.error "Failed: #{e}"

      # Return a default hash which just mirrors each key
      Hash.new { |_, key| key.to_s }
    end
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
    raw_record_hash.except(*config.senec_ignore)
  end

  def raw_record_hash # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
    {
      measure_time:,
      case_temp:,
      inverter_power:,
      mpp1_power:,
      mpp2_power:,
      mpp3_power:,
      power_ratio:,
      house_power:,
      bat_power_plus:,
      bat_power_minus:,
      bat_fuel_charge:,
      bat_charge_current:,
      bat_voltage:,
      ev_connected:,
      wallbox_charge_power:,
      wallbox_charge_power0: wallbox_charge_power(0),
      wallbox_charge_power1: wallbox_charge_power(1),
      wallbox_charge_power2: wallbox_charge_power(2),
      wallbox_charge_power3: wallbox_charge_power(3),
      grid_power_plus:,
      grid_power_minus:,
      current_state:,
      current_state_code:,
      current_state_ok:,
      application_version:,
      response_duration:,
    }
  end

  def data
    @data ||= Senec::Local::Request.new connection:, state_names:
  end

  def success_message(record)
    [
      "\nGot record ##{record.id} at " \
      "#{Time.at(record.measure_time).localtime} " \
      "within #{record.response_duration} ms",
      record.current_state,
      ("Inverter #{record.inverter_power} W" unless config.excludes?(:inverter_power)),
      ("House #{record.house_power} W" unless config.excludes?(:house_power)),
      ("Wallbox #{record.wallbox_charge_power} W" unless config.excludes?(:wallbox_charge_power)),
    ].compact.join(', ')
  end

  def failure_message(error)
    "Error getting data from SENEC at #{config.senec_url}: #{error}"
  end

  def response_duration
    (data.response_duration * 1000).round
  end

  def measure_time
    data.measure_time
  end

  def current_state_code
    data.current_state_code
  end

  def current_state
    data.current_state_name
  end

  OK_STATES = [
    13, # BATTERY FULL
    14, # CHARGE
    15, # BATTERY EMPTY
    16, # DISCHARGE
    17, # PV + DISCHARGE
    18, # GRID + DISCHARGE
    21, # OWN CONSUMPTION
    54, # ABSORPTION PHASE
    56, # PEAK-SHAVING: WAIT
    88, # DISCHARGE PROHIBITED
    89, # SPARE CAPACITY
  ].freeze
  private_constant :OK_STATES

  def current_state_ok # rubocop:disable Naming/PredicateMethod
    OK_STATES.include? current_state_code
  end

  def case_temp
    data.case_temp
  end

  def application_version
    data.application_version
  end

  def inverter_power
    data.inverter_power.round
  end

  def mpp1_power
    data.mpp_power[0]&.round
  end

  def mpp2_power
    data.mpp_power[1]&.round
  end

  def mpp3_power
    data.mpp_power[2]&.round
  end

  def power_ratio
    data.power_ratio
  end

  def house_power
    data.house_power.round
  end

  def bat_power_plus
    data.bat_power.positive? ? data.bat_power.round : 0
  end

  def bat_power_minus
    data.bat_power.negative? ? -data.bat_power.round : 0
  end

  def bat_fuel_charge
    data.bat_fuel_charge
  end

  def bat_charge_current
    data.bat_charge_current
  end

  def bat_voltage
    data.bat_voltage
  end

  def ev_connected # rubocop:disable Naming/PredicateMethod
    data.ev_connected.any?(&:positive?)
  end

  def wallbox_charge_power(index = nil)
    if index
      data.wallbox_charge_power[index].round
    else
      data.wallbox_charge_power.sum.round
    end
  end

  def grid_power_plus
    data.grid_power.positive? ? data.grid_power.round : 0
  end

  def grid_power_minus
    data.grid_power.negative? ? -data.grid_power.round : 0
  end
end
