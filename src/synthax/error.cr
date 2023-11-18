module Sthx
  # An exception raised when parsing fails.
  class SyntaxError < Exception
    # Returns the `Sthx::Err` object.
    getter err

    def initialize(@err : Err)
    end
  end
end
