require 'stdout_logger'

describe StdoutLogger do
  let(:logger) { described_class.new }

  let(:message) { 'This is the message' }

  describe '#info' do
    subject(:info) { logger.info(message) }

    it { expect { info }.to output(/#{message}/).to_stdout }
  end

  describe '#error' do
    subject(:error) { logger.error(message) }

    it { expect { error }.to output(/#{message}/).to_stdout }
    it { expect { error }.to output(/\e\[31m/).to_stdout }
  end
end
