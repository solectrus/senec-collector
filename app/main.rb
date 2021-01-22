#!/usr/bin/env ruby

require 'dotenv/load'
require 'influxdb-client'

require_relative 'senec_loop'
require_relative 'forecast_loop'

# Flush output immediately
$stdout.sync = true

[
  Thread.new { SenecLoop.start },
  Thread.new { ForecastLoop.start }
].each(&:join)
