require 'loop'
require 'config'

describe Loop do
  let(:config) { Config.from_env(senec_adapter: :local, senec_interval: 5) }
  let(:logger) { MemoryLogger.new }

  before { config.logger = logger }

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
