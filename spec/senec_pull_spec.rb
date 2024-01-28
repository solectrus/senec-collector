require 'senec_pull'
require 'config'

describe SenecPull do
  let(:queue) { Queue.new }
  let(:config) { Config.from_env }
  let(:senec_pull) do
    silence_stream($stdout) do
      described_class.new(config:, queue:).tap do |senec_pull|
        VCR.use_cassette('senec_state_names') { senec_pull.senec_state_names }
      end
    end
  end

  describe '#next' do
    context 'when successful' do
      it 'increments the queue length' do
        VCR.use_cassette('senec_success') { senec_pull.next }

        expect(queue.length).to eq(1)
      end
    end

    context 'when it fails' do
      it 'raises Senec::Local::Error and does not increment queue length' do
        allow(Senec::Local::Request).to receive(:new).and_raise(Senec::Local::Error)

        expect { senec_pull.next }.to raise_error(Senec::Local::Error)
        expect(queue.length).to eq(0)
      end
    end
  end
end
