require 'local_adapter'
require 'cloud_adapter'
require 'blank'
require 'null_logger'

KEYS = %i[
  senec_adapter
  senec_host
  senec_schema
  senec_interval
  senec_language
  senec_username
  senec_password
  senec_system_id
  influx_schema
  influx_host
  influx_port
  influx_token
  influx_org
  influx_bucket
  influx_measurement
].freeze

DEFAULTS = {
  senec_adapter: :local,
  senec_schema: :https,
  senec_language: :de,
  influx_schema: :https,
  influx_port: 8086,
  influx_measurement: 'SENEC',
}.freeze

Config =
  Struct.new(*KEYS, keyword_init: true) do
    def initialize(*options)
      super

      set_defaults_and_types
      validate!
    end

    def set_defaults_and_types
      convert_types
      set_defaults
    end

    def convert_types
      # Strip blanks
      KEYS.each do |key|
        self[key] = self[key].presence
      end

      # Symbols
      %i[senec_adapter senec_schema senec_language influx_schema].each do |key|
        self[key] = self[key]&.to_sym
      end

      # Integer
      %i[senec_interval influx_port].each do |key|
        self[key] = self[key]&.to_i
      end
    end

    def set_defaults
      DEFAULTS.each do |key, value|
        self[key] ||= value
      end

      self[:senec_interval] ||= senec_adapter == :local ? 5 : 60
    end

    def validate!
      validate_senec_adapter!

      case senec_adapter
      when :local
        validate_url!(senec_url)
      when :cloud
        validate_senec_credentials!
      end

      validate_influx_settings!
      validate_interval!(senec_interval)
    end

    def influx_url
      "#{influx_schema}://#{influx_host}:#{influx_port}"
    end

    def senec_url
      "#{senec_schema}://#{senec_host}"
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

    attr_writer :logger

    def logger
      @logger ||= NullLogger.new
    end

    private

    def validate_senec_adapter!
      %i[local cloud].include?(senec_adapter) || throw("SENEC_ADAPTER is invalid: #{senec_adapter}")
    end

    def validate_interval!(interval)
      (interval.is_a?(Integer) && interval.positive?) || throw("SENEC_INTERVAL is invalid: #{interval}")
    end

    def validate_senec_credentials!
      %i[senec_username senec_password].each do |key|
        self[key].present? || throw("#{key.to_s.upcase} is missing")
      end

      senec_username.include?('@') || throw('SENEC_USERNAME is invalid')
    end

    def validate_influx_settings!
      %i[
        influx_schema
        influx_host
        influx_port
        influx_org
        influx_bucket
        influx_token
        influx_measurement
      ].each do |key|
        self[key].present? || throw("#{key.to_s.upcase} is missing")
      end

      validate_url!(influx_url)
    end

    def validate_url!(url)
      uri = URI.parse(url)

      (uri.is_a?(URI::HTTP) && uri.host.present?) || throw("URL is invalid: #{url}")
    end

    def self.from_env(options = {})
      new(
        {
          senec_adapter: ENV.fetch('SENEC_ADAPTER', nil),
          senec_host: ENV.fetch('SENEC_HOST', nil),
          senec_schema: ENV.fetch('SENEC_SCHEMA', nil),
          senec_interval: ENV.fetch('SENEC_INTERVAL', nil),
          senec_language: ENV.fetch('SENEC_LANGUAGE', nil),
          senec_username: ENV.fetch('SENEC_USERNAME', nil),
          senec_password: ENV.fetch('SENEC_PASSWORD', nil),
          senec_system_id: ENV.fetch('SENEC_SYSTEM_ID', nil),
          influx_host: ENV.fetch('INFLUX_HOST'),
          influx_schema: ENV.fetch('INFLUX_SCHEMA', nil),
          influx_port: ENV.fetch('INFLUX_PORT', nil),
          influx_token: ENV.fetch('INFLUX_TOKEN'),
          influx_org: ENV.fetch('INFLUX_ORG'),
          influx_bucket: ENV.fetch('INFLUX_BUCKET', nil),
          influx_measurement: ENV.fetch('INFLUX_MEASUREMENT', nil),
        }.merge(options),
      )
    end
  end
