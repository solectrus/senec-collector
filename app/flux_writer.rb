module FluxWriter
  def influx_host
    @influx_host ||= ENV.fetch('INFLUX_HOST')
  end

  def influx_token
    @influx_token ||= ENV.fetch('INFLUX_TOKEN')
  end

  def influx_org
    @influx_org ||= ENV.fetch('INFLUX_ORG')
  end

  def influx_bucket
    @influx_bucket ||= ENV.fetch('INFLUX_BUCKET')
  end

  def influx_client
    @influx_client ||= InfluxDB2::Client.new(
      influx_host,
      influx_token,
      precision: InfluxDB2::WritePrecision::SECOND
    )
  end

  def write_api
    @write_api ||= influx_client.create_write_api
  end
end
