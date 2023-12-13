class SenecStateNames
  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def fetch
    puts "Getting state names (language: #{config.senec_language}) from SENEC by parsing source code..."
    names =
      Senec::Local::State.new(connection: config.senec_connection).names(
        language: config.senec_language,
      )
    puts "OK, got #{names.length} state names"
    names
  end
end
