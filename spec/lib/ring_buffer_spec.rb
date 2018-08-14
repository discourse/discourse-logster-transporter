require 'rails_helper'

RSpec.describe RingBuffer do
  it 'should work correctly' do
    buffer = RingBuffer.new(3)

    buffer << 1

    expect(buffer).to eq([1])

    buffer.push(2)

    expect(buffer).to eq([1, 2])

    buffer.push(3)

    expect(buffer).to eq([1, 2, 3])

    buffer << 4

    expect(buffer).to eq([2, 3, 4])
  end
end
