require 'json'
require 'fileutils'
require 'solectrus_record'

# Saves buffered records to a file on shutdown and restores them on the next start.
# Without a volume, the file is kept in the container layer, so it survives a
# restart of the container, but not its recreation.
class BufferStore
  DEFAULT_PATH = File.expand_path('../data/buffer.jsonl', __dir__)

  def initialize(logger:, path: DEFAULT_PATH)
    @logger = logger
    @path = path
  end

  attr_reader :logger, :path

  def save(records)
    return if records.empty?

    write(records)
    logger.info "Saved #{records.size} buffered records to #{path}"
  rescue SystemCallError => e
    logger.error "Could not save #{records.size} buffered records: #{e.message}"
  end

  def load
    records = File.foreach(path).filter_map { |line| deserialize(line) }
    File.delete(path)

    logger.info "Restored #{records.size} buffered records from #{path}"
    records
  rescue Errno::ENOENT
    []
  rescue SystemCallError => e
    logger.error "Could not restore buffered records: #{e.message}"
    []
  end

  private

  # Write to a temporary file first, so an aborted write does not leave a broken file
  def write(records)
    FileUtils.mkdir_p(File.dirname(path))

    tmp_path = "#{path}.tmp"
    File.open(tmp_path, 'w') do |file|
      records.each { |record| file.puts(serialize(record)) }
    end
    File.rename(tmp_path, path)
  end

  def serialize(record)
    JSON.generate({ id: record.id, payload: record.to_hash }, allow_nan: true)
  end

  def deserialize(line)
    hash = JSON.parse(line, symbolize_names: true, allow_nan: true)
    SolectrusRecord.new(hash[:id], hash[:payload])
  rescue JSON::ParserError => e
    logger.error "Skipping invalid buffered record: #{e.message}"
    nil
  end
end
