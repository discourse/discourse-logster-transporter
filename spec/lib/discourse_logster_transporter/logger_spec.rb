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

      expect(logger.buffer.length).to eq(4)

      first_log = logger.buffer.first

      expect(first_log[0]).to eq(2)
      expect(first_log[1]).to eq(nil)
      expect(first_log[2]).to eq('test')

      expect(first_log[3].keys).to contain_exactly(:env, :backtrace)

      expect(first_log[3][:env].keys).to contain_exactly(
        "application_version",
        "hostname",
        "process_id"
      )
    end
  end
end
