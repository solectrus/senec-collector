class SolectrusRecord
  def initialize(senec_data)
    @senec_data = senec_data
  end

  def valid?
    !measure_time.nil?
  end

  def to_hash
    {
      case_temp:,
      inverter_power:,
      house_power:,
      bat_power_plus:,
      bat_power_minus:,
      bat_fuel_charge:,
      bat_charge_current:,
      bat_voltage:,
      wallbox_charge_power:,
      grid_power_plus:,
      grid_power_minus:
    }
  end

  def measure_time
    @senec_data.measure_time
  end

  def case_temp
    @senec_data.case_temp
  end

  def inverter_power
    @senec_data.inverter_power.round
  end

  def house_power
    @senec_data.house_power.round
  end

  def bat_power_plus
    @senec_data.bat_power.positive? ? @senec_data.bat_power.round : 0
  end

  def bat_power_minus
    @senec_data.bat_power.negative? ? -@senec_data.bat_power.round : 0
  end

  def bat_fuel_charge
    @senec_data.bat_fuel_charge
  end

  def bat_charge_current
    @senec_data.bat_charge_current
  end

  def bat_voltage
    @senec_data.bat_voltage
  end

  def wallbox_charge_power
    @senec_data.wallbox_charge_power.sum.round
  end

  def grid_power_plus
    @senec_data.grid_power.positive? ? @senec_data.grid_power.round : 0
  end

  def grid_power_minus
    @senec_data.grid_power.negative? ? -@senec_data.grid_power.round : 0
  end
end
