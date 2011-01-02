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


    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def chain(*actions)
        actions.inject(&:>>)
      end
    end
  end
end
