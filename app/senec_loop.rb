require 'senec'

class SenecLoop
  def self.start
    new.start
  end

  def start
    puts "Starting SENEC collector...\n\n"

    loop do
      push_to_influx(senec_data)

      puts "Sleeping #{interval} seconds ..."
      sleep interval
    end
  end

  private

  attr_accessor :count

  def senec_data
    self.count ||= 0
    self.count += 1

    puts "\n-------------------------------------------------------\n"
    print "##{count}: Getting data from SENEC at #{senec_host} ... "
    request = Senec::Request.new host: senec_host
    puts 'OK'

    puts "\n"
    puts "  PV production: #{request.inverter_power} W"
    puts "  House power consumption: #{request.house_power} W"
    puts "\n"

    puts "  Battery charge power: #{request.bat_power} W"
    puts "  Battery fuel charge: #{request.bat_fuel_charge} %"
    puts "  Battery charge current: #{request.bat_charge_current} A"
    puts "  Battery voltage: #{request.bat_voltage} V"
    puts "\n"

    puts "  Wallbox charge power: #{request.wallbox_charge_power.sum} W"
    puts "\n"

    puts "  Grid power: #{request.grid_power} W"
    puts "  Current state of the system: #{request.current_state}"
    puts "\n"

    request
  end

  def push_to_influx(request)
    point = InfluxDB2::Point.new(name: measurement)
              .add_field('inverter_power',       request.inverter_power)
              .add_field('house_power',          request.house_power)
              .add_field('bat_power_plus',       request.bat_power.positive? ? request.bat_power : 0)
              .add_field('bat_power_minus',      request.bat_power.negative? ? -request.bat_power : 0)
              .add_field('bat_fuel_charge',      request.bat_fuel_charge)
              .add_field('bat_charge_current',   request.bat_charge_current)
              .add_field('bat_voltage',          request.bat_voltage)
              .add_field('wallbox_charge_power', request.wallbox_charge_power.sum)
              .add_field('grid_power_plus',      request.grid_power.positive? ? request.grid_power : 0)
              .add_field('grid_power_minus',     request.grid_power.negative? ? -request.grid_power : 0)

    print 'Pushing SENEC data to InfluxDB ... '
    write_api.write(data: point, bucket: influx_bucket, org: influx_org)
    puts 'OK'
  end

  def senec_host
    @senec_host ||= ENV.fetch('SENEC_HOST')
  end

  def influx_host
    @influx_host ||= ENV.fetch('INFLUX_HOST')
  end

  def influx_token
    @influx_token ||= ENV.fetch('INFLUX_TOKEN')
  end

  def influx_org
    @influx_org ||= ENV.fetch('INFLUX_ORG')
  end

  def influx_bucket
    @influx_bucket ||= ENV.fetch('INFLUX_BUCKET')
  end

  def measurement
    'SENEC'
  end

  def interval
    @interval ||= ENV.fetch('INTERVAL', 5).to_i
  end

  def influx_client
    @influx_client ||= InfluxDB2::Client.new(
      influx_host,
      influx_token,
      precision: InfluxDB2::WritePrecision::SECOND
    )
  end

  def write_api
    @write_api ||= influx_client.create_write_api
  end
end
