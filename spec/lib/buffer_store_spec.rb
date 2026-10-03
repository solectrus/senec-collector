require 'buffer_store'
require 'tmpdir'

describe BufferStore do
  subject(:store) { described_class.new(logger:, path:) }

  let(:logger) { MemoryLogger.new }
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'data', 'buffer.jsonl') }

  let(:records) do
    [1, 2].map do |id|
      payload = { measure_time: 1_700_000_000 + id, house_power: 500, bat_fuel_charge: 80.0 }
      SolectrusRecord.new(id, payload.merge(current_state: 'LADEN', ev_connected: id.even?))
    end
  end

  after { FileUtils.remove_entry(dir) }

  describe '#save and #load' do
    it 'restores the records with the same values and types' do
      store.save(records)
      restored = store.load

      expect(restored.map(&:id)).to eq([1, 2])
      expect(restored.map(&:to_hash)).to eq(records.map(&:to_hash))
      expect(restored.first.bat_fuel_charge).to be_a(Float)
    end

    it 'deletes the file after loading' do
      store.save(records)
      store.load

      expect(File.exist?(path)).to be(false)
    end

    it 'logs the number of records' do
      store.save(records)
      store.load

      expect(logger.info_messages).to include(/Saved 2 buffered records/, /Restored 2 buffered records/)
    end
  end

  describe '#save' do
    it 'does not create a file without records' do
      store.save([])

      expect(File.exist?(path)).to be(false)
    end

    it 'logs an error if the file cannot be written' do
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.chmod(0o500, File.dirname(path))

      store.save(records)

      expect(logger.error_messages).to include(/Could not save 2 buffered records/)
    ensure
      FileUtils.chmod(0o700, File.dirname(path))
    end
  end

  describe '#load' do
    it 'returns nothing if there is no file' do
      expect(store.load).to eq([])
    end

    it 'skips invalid lines' do
      store.save(records)
      File.write(path, "invalid\n", mode: 'a')

      expect(store.load.size).to eq(2)
      expect(logger.error_messages).to include(/Skipping invalid buffered record/)
    end
  end
end
