require 'null_logger'

describe NullLogger do
  describe '#info' do
    subject(:info) { described_class.new.info('message') }

    it 'does nothing' do
      expect { info }.not_to raise_error
    end
  end

  describe '#error' do
    subject(:error) { described_class.new.error('message') }

    it 'does nothing' do
      expect { error }.not_to raise_error
    end
  end
end
