require 'senec_state_names'
require 'senec'
require 'config'

describe SenecStateNames do
  describe '#fetch' do
    let(:config) { Config.from_env }
    let(:senec_state_names) { described_class.new(config:) }

    it 'fetches and sorts state names correctly' do
      expect do
        VCR.use_cassette('senec_state_names') do
          state_names = senec_state_names.fetch

          expect(state_names.keys.sort).to eq((0..98).to_a)
        end
      end.to output("Getting state names (language: de) from SENEC by parsing source code...\nOK, got 99 state names\n").to_stdout
    end
  end
end
