require File.join(File.dirname(__FILE__), *%w[.. default_deferrable])

module DeferrableGratification
  module Combinators
    class Bind < DefaultDeferrable
      def initialize(first, second)
        @first = first
        @second = second
      end

      def go(*args)
        @first.callback {|*args| @second.go(*args) }
        @second.callback {|*args| self.succeed(*args) }

        @first.errback {|*args| self.fail(*args) }
        @second.errback {|*args| self.fail(*args) }

        @first.go(*args)

        self
      end
    end
  end
end
