class SolectrusRecord
  def initialize(id, payload)
    @id = id
    @payload = payload
  end

  attr_reader :id

  def to_hash
    @payload
  end

  %i[
    measure_time
    case_temp
    inverter_power
    mpp1_power
    mpp2_power
    mpp3_power
    power_ratio
    house_power
    bat_power_plus
    bat_power_minus
    bat_fuel_charge
    bat_charge_current
    bat_voltage
    wallbox_charge_power
    wallbox_charge_power0
    wallbox_charge_power1
    wallbox_charge_power2
    wallbox_charge_power3
    grid_power_plus
    grid_power_minus
    current_state
    current_state_code
    current_state_ok
    application_version
    response_duration
  ].each do |method|
    define_method(method) do
      @payload[method]
    end
  end
end
