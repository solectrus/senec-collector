require 'test_helper'

class ConfigTest < Minitest::Test
  VALID_OPTIONS = {
    senec_host: '1.2.3.4',
    senec_schema: 'http',
    senec_interval: 5,
    influx_host: 'influx.example.com',
    influx_schema: 'https',
    influx_port: '443',
    influx_token: 'this.is.just.an.example',
    influx_org: 'solectrus',
    influx_bucket: 'SENEC',
    influx_measurement: 'SENEC',
  }.freeze

  def test_valid_options
    Config.new(VALID_OPTIONS)
  end

  def test_invalid_options
    assert_raises(Exception) { Config.new({}) }

    error =
      assert_raises(Exception) do
        Config.new(VALID_OPTIONS.merge(senec_interval: 0))
      end

    assert_match(/Interval is invalid/, error.message)

    error =
      assert_raises(Exception) do
        Config.new(VALID_OPTIONS.merge(influx_schema: 'foo'))
      end

    assert_match(/URL is invalid/, error.message)
  end

  def test_senec_methods
    config = Config.new(VALID_OPTIONS)

    assert_equal '1.2.3.4', config.senec_host
    assert_equal 'http', config.senec_schema
    assert_equal 5, config.senec_interval
  end

  def test_influx_methods
    config = Config.new(VALID_OPTIONS)

    assert_equal 'influx.example.com', config.influx_host
    assert_equal 'https', config.influx_schema
    assert_equal '443', config.influx_port
    assert_equal 'this.is.just.an.example', config.influx_token
    assert_equal 'solectrus', config.influx_org
    assert_equal 'SENEC', config.influx_bucket
    assert_equal 'SENEC', config.influx_measurement
  end
end
