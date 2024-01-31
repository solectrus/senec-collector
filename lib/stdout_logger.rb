class StdoutLogger
  def initialize
    # Flush output immediately
    $stdout.sync = true
  end

  def info(message)
    puts message
  end

  def error(message)
    # Red text by using ANSI escape code
    puts "\e[31m#{message}\e[0m"
  end
end
