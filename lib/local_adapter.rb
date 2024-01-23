require 'solectrus_record'

class LocalAdapter
  def initialize(config:)
    @config = config
  end

  attr_reader :config
  attr_accessor :message_handler

  def init_message
    "Pulling from your local SENEC at #{senec_url} every #{config.senec_interval} seconds"
  end

  def connection
    @connection ||=
      Senec::Local::Connection.new(host: config.senec_host, schema: config.senec_schema)
  end

  def state_names
    @state_names ||= begin
      send_message "Getting state names (language: #{config.senec_language}) from SENEC by parsing source code..."

      names =
        Senec::Local::State.new(connection:).names(
          language: config.senec_language,
        )
      send_message "OK, got #{names.length} state names"
      names
    end
  end

  def solectrus_record(id = 1) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    # Reset data cache
    @data = nil

    SolectrusRecord.new(id,
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
                        response_duration:,).tap do |record|
                          send_message success_message(record)
                        end
  rescue StandardError => e
    send_message failure_message(e)
    nil
  end

  def send_message(message)
    message_handler&.call(message)
  end

  private

  def senec_url
    "#{config.senec_schema}://#{config.senec_host}"
  end

  def data
    @data ||= Senec::Local::Request.new connection:, state_names:
  end

  def success_message(record)
    "\nGot record ##{record.id} at " \
      "#{Time.at(record.measure_time)} " \
      "within #{record.response_duration} ms, " \
      "#{record.current_state}, " \
      "Inverter #{record.inverter_power} W, House #{record.house_power} W, " \
      "Wallbox #{record.wallbox_charge_power} W"
  end

  def failure_message(error)
    "Error getting data from SENEC at #{senec_url}: #{error}"
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
    56, # PEAK-SHAVING: WAIT"
  ].freeze

  def current_state_ok
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
