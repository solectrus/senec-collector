require 'loop'
require 'config'

describe Loop do
  let(:config) { Config.from_env(senec_adapter: :local, senec_interval: 5) }
  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  describe '#start' do
    it 'outputs the correct information when started', vcr: 'senec-local' do
      VCR.use_cassette('influx-success') do
        described_class.start(config:, max_count: 2)
      end

      expect(logger.info_messages).to include(/Got record #1/)
    end

    it 'handles Interrupt' do
      allow(config.adapter).to receive(:data).and_raise(SystemExit)

      described_class.start(config:)

      expect(logger.error_messages).to include(/Exiting/)
    end

    it 'handles errors' do
      allow(config.adapter).to receive(:data).and_raise(StandardError)

      described_class.start(config:, max_count: 1)

      expect(logger.error_messages).to include(/Error getting data/)
    end
  end
end
