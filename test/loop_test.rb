require 'test_helper'
require 'loop'
require 'config'

class LoopTest < Minitest::Test
  OPTIONS = {
    senec_host: ENV['SENEC_HOST'],
    senec_interval: ENV['SENEC_INTERVAL'].to_i,
    influx_host: ENV['INFLUX_HOST'],
    influx_schema: ENV['INFLUX_SCHEMA'],
    influx_port: ENV['INFLUX_PORT'],
    influx_token: ENV['INFLUX_TOKEN'],
    influx_org: ENV['INFLUX_ORG'],
    influx_bucket: ENV['INFLUX_BUCKET']
  }.freeze

  def test_start
    config = Config.new(OPTIONS)

    VCR.use_cassette('senec_success') do
      VCR.use_cassette('influxdb') do
        Loop.start(config:, max_count: 1)
      end
    end
  end
end
