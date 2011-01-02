require 'eventmachine'
require 'em/deferrable'
require File.join(File.dirname(__FILE__), 'combinators')

module EventMachine::Deferrable
  module CombinatorOperators
    def >>(subsequent)
      ::EventMachine::Deferrable::Combinators::Bind.new(self, subsequent)
    end

    def <<(previous)
      previous >> self
    end
  end
end
