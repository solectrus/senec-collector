require 'blank'

describe 'String' do
  describe '#blank?' do
    it 'returns true if the string is empty' do
      expect('').to be_blank
    end

    it 'returns true if the string contains only spaces' do
      expect('   ').to be_blank
    end

    it 'returns false if the string contains non-space characters' do
      expect('  a  ').not_to be_blank
    end
  end

  describe '#present?' do
    it 'returns false if the string is empty' do
      expect('').not_to be_present
    end

    it 'returns false if the string contains only spaces' do
      expect('   ').not_to be_present
    end

    it 'returns true if the string contains non-space characters' do
      expect('  a  ').to be_present
    end
  end
end
