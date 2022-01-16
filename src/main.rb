#!/usr/bin/env ruby

require 'dotenv/load'
require_relative 'loop'
require_relative 'config'

# Flush output immediately
$stdout.sync = true

puts 'SENEC collector for SOLECTRUS'
puts 'https://github.com/solectrus/senec-collector'
puts 'Copyright (c) 2020,2022 Georg Ledermann, released under the MIT License'
puts "\n"

config = Config.from_env

puts "Using Ruby #{RUBY_VERSION} on platform #{RUBY_PLATFORM}"
puts "Pulling from SENEC at #{config.senec_host} every #{config.senec_interval} seconds"
puts "Pushing to InfluxDB at #{config.influx_url}, bucket #{config.influx_bucket}"
puts "\n"

Loop.start(config:)
