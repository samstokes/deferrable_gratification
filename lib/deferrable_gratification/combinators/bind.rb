require 'eventmachine'
require 'em/deferrable'

module EventMachine::Deferrable
  module Combinators
    class Bind
      include ::EventMachine::Deferrable

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
