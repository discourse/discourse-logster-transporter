require 'rails_helper'

RSpec.describe DiscourseLogsterTransporter::Logger do
  let(:root_url) { 'https://test.somesite.org' }
  let(:logger) { described_class.new(root_url: root_url, key: '') }

  describe '#add' do
    it 'should add the right message into the buffer' do
      logger.warn('test')
      logger.error('test2')
      logger.warn { 'test3' }
      logger.add(1, 'test4', 'somename') { 'omg' }

      expect(logger.buffer).to eq([
        [2, nil, 'test'],
        [3, nil, 'test2'],
        [2, 'test3', nil],
        [1, 'test4', 'somename']
      ])
    end
  end
end
