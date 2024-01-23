require 'local_adapter'
require 'cloud_adapter'

Config =
  Struct.new(
    :senec_adapter,
    :senec_host,
    :senec_schema,
    :senec_interval,
    :senec_language,
    :senec_username,
    :senec_password,
    :senec_system_id,
    :influx_schema,
    :influx_host,
    :influx_port,
    :influx_token,
    :influx_org,
    :influx_bucket,
    :influx_measurement,
    keyword_init: true,
  ) do
    def initialize(*options)
      super

      case senec_adapter
      when :local
        validate_senec_host!
      when :cloud
        validate_senec_credentials!
      end

      validate_url!(influx_url)
      validate_interval!(senec_interval)
    end

    def influx_url
      "#{influx_schema}://#{influx_host}:#{influx_port}"
    end

    def adapter
      @adapter ||=
        case senec_adapter
        when :local
          LocalAdapter.new(config: self)
        when :cloud
          CloudAdapter.new(config: self)
        end
    end

    private

    def validate_interval!(interval)
      return if interval.is_a?(Integer) && interval.positive?

      throw "Interval is invalid: #{interval}"
    end

    def validate_url!(url)
      uri = URI.parse(url)
      return if uri.is_a?(URI::HTTP) && !uri.host.nil?

      throw "URL is invalid: #{url}"
    end

    def validate_senec_credentials!
      !senec_username.nil? && !senec_password.nil?
    end

    def validate_senec_host!
      !senec_host.nil? && %w[http https.include].include?(senec_schema)
    end

    def self.from_env(options = {}) # rubocop:disable Metrics/AbcSize
      new(
        {
          senec_adapter: ENV.fetch('SENEC_ADAPTER', 'local').to_sym,
          senec_host: ENV.fetch('SENEC_HOST', nil),
          senec_schema: ENV.fetch('SENEC_SCHEMA', 'http'),
          senec_interval: ENV.fetch('SENEC_INTERVAL').to_i,
          senec_language: ENV.fetch('SENEC_LANGUAGE', 'de').to_sym,
          senec_username: ENV.fetch('SENEC_USERNAME', nil),
          senec_password: ENV.fetch('SENEC_PASSWORD', nil),
          senec_system_id: ENV.fetch('SENEC_SYSTEM_ID', nil),
          influx_host: ENV.fetch('INFLUX_HOST'),
          influx_schema: ENV.fetch('INFLUX_SCHEMA', 'http'),
          influx_port: ENV.fetch('INFLUX_PORT', '8086'),
          influx_token: ENV.fetch('INFLUX_TOKEN'),
          influx_org: ENV.fetch('INFLUX_ORG'),
          influx_bucket: ENV.fetch('INFLUX_BUCKET'),
          influx_measurement: ENV.fetch('INFLUX_MEASUREMENT', 'SENEC'),
        }.merge(options),
      )
    end
  end
