# frozen_string_literal: true

class RingBuffer < ::Array
  def initialize(max_size)
    @max_size = max_size.to_i
  end

  def <<(element)
    if self.size < @max_size
      super
    else
      self.shift
      self.push(element)
    end
  end

  alias :push :<<
end
