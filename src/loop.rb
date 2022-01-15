require_relative 'flux_writer'
require_relative 'senec_data'

class Loop
  def self.start(config:, max_count: nil)
    new(config:, max_count:).start
  end

  def initialize(config:, max_count:)
    @config = config
    @max_count = max_count
  end

  attr_reader :config, :max_count
  attr_accessor :count

  def start
    self.count = 0
    loop do
      self.count += 1

      puts "##{count} --- "
      push(solectrus_record)
      break if max_count && count >= max_count

      puts "Sleeping #{config.senec_interval} seconds ...\n\n"
      sleep config.senec_interval
    end
  end

  private

  def solectrus_record
    print "Getting data from SENEC at #{config.senec_host} ... "

    begin
      record = SenecData.new(config.senec_host).solectrus_record
      puts " PV #{record.inverter_power} W\n"
      record
    rescue StandardError => e
      puts "Error #{e}"
    end
  end

  def push(record)
    print 'Pushing SENEC data to InfluxDB ... '
    FluxWriter.push(config:, record:)
    puts 'OK'
  end
end
