require 'dotenv/load'
require 'senec'
require 'influxdb-client'

puts 'Starting SENEC collector...'

senec_host    = ENV.fetch('SENEC_HOST')
influx_host   = ENV.fetch('INFLUX_HOST')
influx_token  = ENV.fetch('INFLUX_TOKEN')
influx_org    = ENV.fetch('INFLUX_ORG')
influx_bucket = ENV.fetch('INFLUX_BUCKET')

# Setup InfluxDB
client = InfluxDB2::Client.new(
  influx_host,
  influx_token,
  precision: InfluxDB2::WritePrecision::SECOND
)
write_api = client.create_write_api

loop do
  # Get data from SENEC
  request = Senec::Request.new host: senec_host

  puts `clear`

  puts "PV production: #{request.inverter_power} W"
  puts "House power consumption: #{request.house_power} W"
  puts "\n"

  puts "Battery charge power: #{request.bat_power} W"
  puts "Battery fuel charge: #{request.bat_fuel_charge} %"
  puts "Battery charge current: #{request.bat_charge_current} A"
  puts "Battery voltage: #{request.bat_voltage} V"
  puts "\n"

  puts "Grid power: #{request.grid_power} W"
  puts "Current state of the system: #{request.current_state}"
  puts "\n"

  # Push data to InfluxDB
  point = InfluxDB2::Point.new(name: 'SENEC')
                          .add_field('inverter_power',     request.inverter_power)
                          .add_field('house_power',        request.house_power)
                          .add_field('bat_power_plus',     request.bat_power.positive? ? request.bat_power : 0)
                          .add_field('bat_power_minus',    request.bat_power.negative? ? -request.bat_power : 0)
                          .add_field('bat_fuel_charge',    request.bat_fuel_charge)
                          .add_field('bat_charge_current', request.bat_charge_current)
                          .add_field('bat_voltage',        request.bat_voltage)
                          .add_field('grid_power_plus',    request.grid_power.positive? ? request.grid_power : 0)
                          .add_field('grid_power_minus',   request.grid_power.negative? ? -request.grid_power : 0)

  write_api.write(data: point, bucket: influx_bucket, org: influx_org)

  puts 'Successfully pushed to InfluxDB.'

  # Wait
  sleep 5
end
