#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

$LOAD_PATH.unshift(File.expand_path('./lib', __dir__))

require 'dotenv/load'
require 'loop'
require 'config'
require 'stdout_logger'

Oj.mimic_JSON

logger = StdoutLogger.new

logger.info 'SENEC collector for SOLECTRUS, ' \
       "Version #{ENV.fetch('VERSION', '<unknown>')}, " \
       "built at #{ENV.fetch('BUILDTIME', '<unknown>')}"
logger.info 'https://github.com/solectrus/senec-collector'
logger.info 'Copyright (c) 2020-2024 Georg Ledermann, released under the MIT License'
logger.info "\n"

config = Config.from_env
config.logger = logger

logger.info "Using Ruby #{RUBY_VERSION} on platform #{RUBY_PLATFORM}"
logger.info "Pushing to InfluxDB at #{config.influx_url}, " \
       "bucket #{config.influx_bucket}, " \
       "measurement #{config.influx_measurement}"
logger.info "\n"

Loop.start(config:)
