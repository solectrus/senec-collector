require 'loop'
require 'config'
require 'tmpdir'

describe Loop do
  let(:config) { Config.from_env(senec_adapter: :local, senec_interval: 5) }
  let(:logger) { MemoryLogger.new }
  let(:dir) { Dir.mktmpdir }
  let(:buffer_path) { File.join(dir, 'buffer.jsonl') }

  before do
    config.logger = logger
    stub_const('BufferStore::DEFAULT_PATH', buffer_path)
  end

  after { FileUtils.remove_entry(dir) }

  describe '#start' do
    it 'outputs the correct information when started' do
      VCR.use_cassette('influx-success') do
        VCR.use_cassette('senec-local') do
          described_class.start(config:, max_count: 2, max_wait: 1)
        end
      end

      expect(logger.info_messages).to include(/Got record #1/)
    end

    it 'starts collecting even if InfluxDB is not ready at startup' do
      allow_any_instance_of(FluxWriter).to receive(:ready?).and_return(false) # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:sleep) # rubocop:disable RSpec/AnyInstance

      VCR.use_cassette('influx-success') do
        VCR.use_cassette('senec-local') do
          described_class.start(config:, max_count: 2, max_wait: 2)
        end
      end

      expect(logger.error_messages).to include(/InfluxDB not ready after 10 seconds, records will be buffered/)
      expect(logger.info_messages).to include(/Got record #2/)
      expect(logger.info_messages).to include(/Successfully pushed/)
    end

    it 'handles Interrupt' do
      allow(config.adapter).to receive(:data).and_raise(SystemExit)

      VCR.use_cassette('influx-success') do
        VCR.use_cassette('senec-local') do
          described_class.start(config:, max_wait: 1)
        end
      end

      expect(logger.error_messages).to include(/Exiting/)
    end

    it 'handles SIGTERM' do
      allow(config.adapter).to receive(:solectrus_record) { send_sigterm }

      VCR.use_cassette('influx-success') do
        VCR.use_cassette('senec-local') do
          described_class.start(config:, max_wait: 1)
        end
      end

      expect(logger.error_messages).to include(/Exiting/)
    end

    it 'restores buffered records on start' do
      BufferStore.new(logger:).save([SolectrusRecord.new(42, { measure_time: 1_700_000_000, house_power: 500 })])

      VCR.use_cassette('influx-success') do
        VCR.use_cassette('senec-local') do
          described_class.start(config:, max_count: 1, max_wait: 1)
        end
      end

      expect(logger.info_messages).to include(/Restored 1 buffered records/)
      expect(logger.info_messages).to include(/Successfully pushed (2 records|record #42)/)
      expect(File.exist?(buffer_path)).to be(false)
    end

    it 'saves buffered records on SIGTERM if InfluxDB is not available' do
      allow(FluxWriter).to receive(:new).and_return(UnavailableFluxWriter.new)
      allow_any_instance_of(described_class).to receive(:sleep) # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(InfluxPush).to receive(:sleep) # rubocop:disable RSpec/AnyInstance
      allow(config.adapter).to receive(:solectrus_record) do |id|
        if id <= 2
          SolectrusRecord.new(id, { measure_time: 1_700_000_000 + id, house_power: 500 })
        elsif id == 3
          send_sigterm
        end
      end

      described_class.start(config:, max_wait: 1)

      expect(BufferStore.new(logger:).load.map(&:id)).to contain_exactly(1, 2)
    end

    it 'handles errors' do
      allow(config.adapter).to receive(:data).and_raise(StandardError)

      VCR.use_cassette('influx-success') do
        described_class.start(config:, max_count: 1, max_wait: 1)
      end

      expect(logger.error_messages).to include(/Error getting data/)
    end
  end

  # Docker sends SIGTERM to the process, so Ruby raises it in the main thread
  def send_sigterm
    Thread.main.raise(SignalException, 'TERM')
    nil
  end
end

class UnavailableFluxWriter
  def ready?
    false
  end

  def push(_records)
    raise Errno::ECONNREFUSED
  end
end
