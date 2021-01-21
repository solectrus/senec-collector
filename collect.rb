require 'dotenv/load'
require 'senec'
require 'influxdb-client'
require './senec_loop'

# Flush output immediately
$stdout.sync = true

senec = Thread.new { SenecLoop.start }
senec.join
