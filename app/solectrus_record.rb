class SolectrusRecord
  def initialize(id, senec_data)
    @id = id
    @senec_data = senec_data
  end

  attr_reader :id, :senec_data

  def to_hash # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    {
      case_temp:,
      inverter_power:,
      mpp1_power:,
      mpp2_power:,
      mpp3_power:,
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
      response_duration:,
    }
  end

  def response_duration
    (senec_data.response_duration * 1000).round
  end

  def measure_time
    senec_data.measure_time
  end

  def current_state_code
    senec_data.current_state_code
  end

  def current_state
    senec_data.current_state_name
  end

  OK_STATES = [
    13, # BATTERY FULL
    14, # CHARGE
    15, # BATTERY EMPTY
    16, # DISCHARGE
    17, # PV + DISCHARGE
    18, # GRID + DISCHARGE
    56, # PEAK-SHAVING: WAIT"
  ].freeze

  def current_state_ok
    OK_STATES.include? current_state_code
  end

  def case_temp
    senec_data.case_temp
  end

  def application_version
    senec_data.application_version
  end

  def inverter_power
    senec_data.inverter_power.round
  end

  def mpp1_power
    senec_data.mpp_power[0]&.round
  end

  def mpp2_power
    senec_data.mpp_power[1]&.round
  end

  def mpp3_power
    senec_data.mpp_power[2]&.round
  end

  def house_power
    senec_data.house_power.round
  end

  def bat_power_plus
    senec_data.bat_power.positive? ? senec_data.bat_power.round : 0
  end

  def bat_power_minus
    senec_data.bat_power.negative? ? -senec_data.bat_power.round : 0
  end

  def bat_fuel_charge
    senec_data.bat_fuel_charge
  end

  def bat_charge_current
    senec_data.bat_charge_current
  end

  def bat_voltage
    senec_data.bat_voltage
  end

  def wallbox_charge_power(index = nil)
    if index
      senec_data.wallbox_charge_power[index].round
    else
      senec_data.wallbox_charge_power.sum.round
    end
  end

  def grid_power_plus
    senec_data.grid_power.positive? ? senec_data.grid_power.round : 0
  end

  def grid_power_minus
    senec_data.grid_power.negative? ? -senec_data.grid_power.round : 0
  end
end
