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
      DeferrableGratification::Combinators::Map.new(self, &block)
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
