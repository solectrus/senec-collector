class FluxWriter
  def initialize(config)
    @config = config
  end

  attr_reader :config

  def ready?
    influx_client.ping.status == 'ok'
  end

  def push(record)
    return unless record

    write_api.write(
      data: point(record),
      bucket: config.influx_bucket,
      org: config.influx_org,
    )
  end

  private

  def point(record)
    InfluxDB2::Point.new(
      name: influx_measurement,
      time: record.measure_time,
      fields: record.to_hash,
    )
  end

  def influx_measurement
    config.influx_measurement
  end

  def influx_client
    @influx_client ||=
      InfluxDB2::Client.new(
        config.influx_url,
        config.influx_token,
        use_ssl: config.influx_schema == :https,
        precision: InfluxDB2::WritePrecision::SECOND,
      )
  end

  def write_api
    @write_api ||= influx_client.create_write_api
  end
end
