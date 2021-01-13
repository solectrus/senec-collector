require 'dotenv/load'
require 'senec'
require 'influxdb-client'

# Flush output immediately
$stdout.sync = true

puts "Starting SENEC collector...\n\n"

print 'Checking ENV variables ... '
senec_host    = ENV.fetch('SENEC_HOST')
influx_host   = ENV.fetch('INFLUX_HOST')
influx_token  = ENV.fetch('INFLUX_TOKEN')
influx_org    = ENV.fetch('INFLUX_ORG')
influx_bucket = ENV.fetch('INFLUX_BUCKET')
interval      = ENV.fetch('INTERVAL', 5).to_i
puts 'OK'

# Setup InfluxDB
print "Connecting to InfluxDB at #{influx_host} ... "
client = InfluxDB2::Client.new(
  influx_host,
  influx_token,
  precision: InfluxDB2::WritePrecision::SECOND
)
write_api = client.create_write_api

puts 'OK'
puts "Starting loop.\n\n"

count = 0
loop do
  count += 1
  puts "\n-------------------------------------------------------\n"

  # Get data from SENEC
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

  # Push data to InfluxDB
  point = InfluxDB2::Point.new(name: 'SENEC')
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

  print 'Pushing to InfluxDB ... '
  write_api.write(data: point, bucket: influx_bucket, org: influx_org)
  puts 'OK'

  # Wait
  puts "Sleeping #{interval} seconds ..."
  sleep interval
end
