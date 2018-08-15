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

      expect(first_log[:severity]).to eq(2)
      expect(first_log[:message]).to eq(nil)
      expect(first_log[:progname]).to eq('test')
      expect(first_log[:backtrace]).to be_present

      expect(first_log[:env].keys).to contain_exactly(
        "application_version",
        "hostname",
        "process_id"
      )
    end
  end
end
