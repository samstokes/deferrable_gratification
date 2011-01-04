require File.join(File.dirname(__FILE__), 'combinators')

module DeferrableGratification
  module CombinatorOperators
    def >>(subsequent)
      Combinators::Bind.new(self, subsequent)
    end

    def <<(previous)
      previous >> self
    end

    def map(&block)
      self >> self.class.lift(&block)
    end


    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def lift(&block)
        DeferrableGratification::Combinators::Lift.new(&block)
      end

      def chain(*actions)
        actions.inject(&:>>)
      end
    end
  end
end
