require File.join(File.dirname(__FILE__), *%w[.. default_deferrable])

module DeferrableGratification
  module Primitives
    # Deferrable whose #go immediately succeeds with a constant value
    class Constant < DefaultDeferrable
      def initialize(value); @value = value; end
      def go; succeed(@value); end
    end
  end
end
