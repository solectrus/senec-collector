require 'net/http'
require_relative 'flux_writer'

class ForecastLoop
  include FluxWriter

  def self.start
    new.start
  end

  def start
    return unless interval.positive?

    puts "Starting forecast collector...\n\n"

    loop do
      push_to_influx(forecast_data)

      puts "Sleeping #{interval} seconds ..."
      sleep interval
    end
  end

  private

  attr_accessor :count

  def push_to_influx(data)
    points = data.map do |key, value|
      InfluxDB2::Point.new(
        name:   influx_measurement,
        time:   key.to_i,
        fields: value
      )
    end

    print 'Pushing forecast to InfluxDB ... '
    write_api.write(data: points, bucket: influx_bucket, org: influx_org)
    puts 'OK'
  end

  def forecast_data
    self.count ||= 0
    self.count += 1

    puts "\n-------------------------------------------------------\n"
    print "##{count}: Getting data from #{uri} ... "
    json = forecast_response
    puts 'OK'

    json.dig('result', 'watts').map do |point|
      [ Time.parse(point[0]), { watt: point[1] } ]
    end.to_h
  end

  def forecast_response
    res = Net::HTTP.get_response(uri)

    case res
    when Net::HTTPOK
      JSON.parse(res.body)
    else
      throw "Failure: #{res.value}"
    end
  end

  def uri
    URI.parse("https://api.forecast.solar/estimate/#{latitude}/#{longitude}/#{declination}/#{azimuth}/#{kwp}?time=utc")
  end

  def influx_measurement
    'Forecast'
  end

  def interval
    @interval ||= ENV['FORECAST_INTERVAL'].to_i
  end

  def latitude
    @latitude ||= ENV.fetch('FORECAST_LATITUDE')
  end

  def longitude
    @longitude ||= ENV.fetch('FORECAST_LONGITUDE')
  end

  def declination
    @declination ||= ENV.fetch('FORECAST_DECLINATION')
  end

  def azimuth
    @azimuth ||= ENV.fetch('FORECAST_AZIMUTH')
  end

  def kwp
    @kwp ||= ENV.fetch('FORECAST_KWP')
  end
end
