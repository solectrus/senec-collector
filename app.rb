#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

$LOAD_PATH.unshift(File.expand_path('./lib', __dir__))

require 'dotenv/load'
require 'loop'
require 'config'

Oj.mimic_JSON

# Flush output immediately
$stdout.sync = true

puts 'SENEC collector for SOLECTRUS, ' \
       "Version #{ENV.fetch('VERSION', '<unknown>')}, " \
       "built at #{ENV.fetch('BUILDTIME', '<unknown>')}"
puts 'https://github.com/solectrus/senec-collector'
puts 'Copyright (c) 2020-2024 Georg Ledermann, released under the MIT License'
puts "\n"

config = Config.from_env
config.adapter.message_handler = ->(message) { puts message }

puts "Using Ruby #{RUBY_VERSION} on platform #{RUBY_PLATFORM}"
puts config.adapter.init_message
puts "Pushing to InfluxDB at #{config.influx_url}, " \
       "bucket #{config.influx_bucket}, " \
       "measurement #{config.influx_measurement}"
puts "\n"

Loop.start(config:)
