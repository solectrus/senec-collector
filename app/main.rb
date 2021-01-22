#!/usr/bin/env ruby

require 'dotenv/load'
require 'influxdb-client'

require_relative 'senec_loop'

# Flush output immediately
$stdout.sync = true

senec = Thread.new { SenecLoop.start }
senec.join
