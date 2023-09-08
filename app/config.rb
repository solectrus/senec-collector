Config =
  Struct.new(
    :senec_host,
    :senec_schema,
    :senec_interval,
    :senec_language,
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

      validate_url!(senec_url)
      validate_url!(influx_url)
      validate_interval!(senec_interval)
    end

    def influx_url
      "#{influx_schema}://#{influx_host}:#{influx_port}"
    end

    def senec_state_names
      @senec_state_names ||=
        begin
          puts "Getting state names (language: #{senec_language}) from SENEC by parsing source code..."
          names =
            Senec::State.new(connection: senec_connection).names(
              language: senec_language,
            )
          puts "OK, got #{names.length} state names"
          names
        end
    end

    def senec_url
      "#{senec_schema}://#{senec_host}"
    end

    def senec_connection
      @senec_connection ||=
        Senec::Connection.new(host: senec_host, schema: senec_schema)
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

    def self.from_env(options = {})
      new(
        {
          senec_host: ENV.fetch('SENEC_HOST'),
          senec_schema: ENV.fetch('SENEC_SCHEMA', 'http'),
          senec_interval: ENV.fetch('SENEC_INTERVAL').to_i,
          senec_language: ENV.fetch('SENEC_LANGUAGE', 'de').to_sym,
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
