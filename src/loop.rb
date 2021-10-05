require 'senec'
require_relative 'flux_writer'

class Loop
  include FluxWriter

  def self.start(max_count: nil)
    new.start(max_count)
  end

  def start(max_count)
    unless interval.positive?
      puts 'Interval missing, stopping.'
      return
    end

    puts "Starting SENEC collector...\n\n"

    self.count = 0
    loop do
      self.count += 1
      push_to_influx(senec_data)
      break if max_count && count >= max_count

      puts "Sleeping #{interval} seconds ..."
      sleep interval
    end
  end

  private

  attr_accessor :count

  def senec_data
    puts "\n-------------------------------------------------------\n"
    print "##{count}: Getting data from SENEC at #{senec_host} ... "

    begin
      data = Senec::Request.new host: senec_host
      puts "  PV #{data.inverter_power} W\n"
      data
    rescue StandardError => e
      puts "Error #{e}"
    end
  end

  def push_to_influx(data)
    return unless data

    point = InfluxDB2::Point.new(name: influx_measurement)
                            .add_field('inverter_power',       data.inverter_power)
                            .add_field('house_power',          data.house_power)
                            .add_field('bat_power_plus',       data.bat_power.positive? ? data.bat_power : 0)
                            .add_field('bat_power_minus',      data.bat_power.negative? ? -data.bat_power : 0)
                            .add_field('bat_fuel_charge',      data.bat_fuel_charge)
                            .add_field('bat_charge_current',   data.bat_charge_current)
                            .add_field('bat_voltage',          data.bat_voltage)
                            .add_field('wallbox_charge_power', data.wallbox_charge_power.sum)
                            .add_field('grid_power_plus',      data.grid_power.positive? ? data.grid_power : 0)
                            .add_field('grid_power_minus',     data.grid_power.negative? ? -data.grid_power : 0)

    print 'Pushing SENEC data to InfluxDB ... '
    write_api.write(data: point, bucket: influx_bucket, org: influx_org)
    puts 'OK'
  end

  def senec_host
    @senec_host ||= ENV.fetch('SENEC_HOST')
  end

  def influx_measurement
    'SENEC'
  end

  def interval
    @interval ||= ENV.fetch('SENEC_INTERVAL', 5).to_i
  end
end
