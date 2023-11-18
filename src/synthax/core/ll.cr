module Sthx::Core
  class LinkedList(T)
    include Enumerable(T)

    def initialize(@value : T, @succ : LinkedList(T)? = nil)
    end

    def self.[](*values : T)
      head = new(values[0])
      values.each(within: 1..) do |value|
        head = head.push(value)
      end
      head
    end

    def each(& : T ->)
      head = self
      while head
        yield head.@value
        head = head.@succ
      end
    end

    def push(value : T)
      LinkedList.new(@value, (succ = @succ) ? succ.push(value) : LinkedList(T).new(value))
    end
  end
end
