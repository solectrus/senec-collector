class MemoryLogger
  def initialize
    @info_messages = []
    @error_messages = []
  end

  attr_reader :info_messages, :error_messages

  def info(message)
    @info_messages << message
  end

  def error(message)
    @error_messages << message
  end
end
