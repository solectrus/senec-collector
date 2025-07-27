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
  senec_ignore
  senec_request_mode
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
  senec_ignore: [],
  senec_request_mode: :minimal,
  influx_schema: :http,
  influx_port: 8086,
  influx_measurement: 'SENEC',
}.freeze

Config =
  Struct.new(*KEYS, keyword_init: true) do
    def initialize(*options)
      super

      set_types
      set_defaults
      limit_senec_interval
      validate!
    end

    def set_types
      KEYS.each do |key|
        self[key] = self[key].presence
        next unless self[key]

        case key
        when :senec_adapter, :senec_schema, :senec_language, :influx_schema,
             :senec_request_mode
          self[key] = self[key].to_sym
        when :senec_interval, :influx_port
          self[key] = self[key].to_i
        when :senec_ignore
          self[key] = self[key].split(',').map(&:to_sym)
        end
      end
    end

    def set_defaults
      DEFAULTS.each do |key, value|
        self[key] ||= value
      end

      self[:senec_interval] ||= senec_adapter == :local ? 5 : 60
    end

    def limit_senec_interval
      minimum = case senec_adapter
                when :local
                  # Be careful with your local SENEC device, do not flood it with queries.
                  # 12 requests/min is the maximum (= 5 seconds interval).
                  5
                when :cloud
                  # Let's be nice to SENEC.
                  # 1 request/min is the maximum (= 60 seconds interval).
                  60
                end

      self[:senec_interval] = minimum if senec_interval < minimum
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
      validate_senec_interval!
      validate_senec_ignore!
      validate_senec_request_mode!
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

    def excludes?(key)
      senec_ignore.include?(key)
    end

    attr_writer :logger

    def logger
      @logger ||= NullLogger.new
    end

    private

    def validate_senec_adapter!
      %i[local cloud].include?(senec_adapter) || throw("SENEC_ADAPTER is invalid: #{senec_adapter}")
    end

    def validate_senec_interval!
      (senec_interval.is_a?(Integer) && senec_interval.positive?) || throw("SENEC_INTERVAL is invalid: #{senec_interval}")
    end

    def validate_senec_credentials!
      %i[senec_username senec_password].each do |key|
        self[key].present? || throw("#{key.to_s.upcase} is missing")
      end

      senec_username.include?('@') || throw('SENEC_USERNAME is invalid')
    end

    def validate_senec_ignore!
      senec_ignore.all? do |key|
        SolectrusRecord::KEYS.include?(key) || throw("SENEC_IGNORE contains unknown field: #{key}")
      end
    end

    def validate_senec_request_mode!
      %i[minimal full].include?(senec_request_mode) ||
        throw("SENEC_REQUEST_MODE is invalid: #{senec_request_mode}")
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
        KEYS.to_h do |key|
          [key, ENV.fetch(key.to_s.upcase, nil)]
        end.merge(options),
      )
    end
  end
