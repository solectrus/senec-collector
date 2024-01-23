class SenecPull
  def initialize(config:, queue:)
    @queue = queue
    @config = config
    @count = 0
  end

  attr_reader :config, :queue, :count

  def next
    record = config.adapter.solectrus_record(@count += 1)
    queue << record

    record
  end
end
