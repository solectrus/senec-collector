require 'app_version'

describe AppVersion do
  describe '.current' do
    subject(:current) { described_class.current }

    around do |example|
      original = ENV.to_h.slice('COMMIT_VERSION', 'VERSION')

      ENV['COMMIT_VERSION'] = commit_version
      ENV['VERSION'] = version
      example.run

      ENV.delete('COMMIT_VERSION')
      ENV.delete('VERSION')
      original.each { |key, value| ENV[key] = value }
    end

    context 'when COMMIT_VERSION is set' do
      let(:commit_version) { 'v0.10.1-3-g2d8f177' }
      let(:version) { 'develop' }

      it { is_expected.to eq('v0.10.1-3-g2d8f177') }
    end

    context 'when COMMIT_VERSION is blank' do
      let(:commit_version) { '' }
      let(:version) { 'develop' }

      it 'falls back to VERSION' do
        expect(current).to eq('develop')
      end
    end

    context 'when both are blank' do
      let(:commit_version) { '' }
      let(:version) { '' }

      it { is_expected.to be_nil }
    end

    context 'when both are unset' do
      let(:commit_version) { nil }
      let(:version) { nil }

      it { is_expected.to be_nil }
    end
  end
end
