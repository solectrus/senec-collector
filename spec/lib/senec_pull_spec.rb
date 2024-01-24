require 'senec_pull'
require 'config'

describe SenecPull do
  let(:queue) { Queue.new }
  let(:config) { Config.from_env(senec_adapter: :local, senec_interval: 5) }
  let(:senec_pull) do
    described_class.new(config:, queue:)
  end

  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  around do |example|
    VCR.use_cassette('senec_success') do
      example.run
    end
  end

  describe '#next' do
    context 'when successful' do
      it 'increments the queue length' do
        senec_pull.next

        expect(queue.length).to eq(1)
      end
    end

    context 'when it fails' do
      it 'raises Senec::Local::Error and does not increment queue length' do
        allow(queue).to receive(:<<).and_raise(Senec::Local::Error)

        expect { senec_pull.next }.to raise_error(Senec::Local::Error)
        expect(queue.length).to eq(0)
      end
    end
  end
end
