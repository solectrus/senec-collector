require_relative 'flux_writer'
require_relative 'senec_data'

class Loop
  attr_accessor :count

  def self.start(max_count: nil)
    new.start(max_count)
  end

  def start(max_count)
    unless interval.positive?
      puts 'Interval missing, stopping.'
      return
    end

    puts "Starting SENEC collector...\n\n"

    self.count = 0
    loop do
      self.count += 1

      puts "##{count} --- "
      push(solectrus_record)
      break if max_count && count >= max_count

      puts "Sleeping #{interval} seconds ...\n\n"
      sleep interval
    end
  end

  private

  def solectrus_record
    print "Getting data from SENEC at #{senec_host} ... "

    begin
      record = SenecData.new(senec_host).solectrus_record
      puts " PV #{record.inverter_power} W\n"
      record
    rescue StandardError => e
      puts "Error #{e}"
    end
  end

  def senec_host
    @senec_host ||= ENV.fetch('SENEC_HOST')
  end

  def interval
    @interval ||= ENV.fetch('SENEC_INTERVAL', 5).to_i
  end

  def push(record)
    print 'Pushing SENEC data to InfluxDB ... '
    FluxWriter.push(record)
    puts 'OK'
  end
end
