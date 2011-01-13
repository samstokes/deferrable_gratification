Dir.glob(File.join(File.dirname(__FILE__), *%w[combinators *.rb])) do |file|
  require file.sub(/\.rb$/, '')
end

module DeferrableGratification
  module Combinators
    def >>(subsequent)
      Bind.new(self, subsequent)
    end

    def bind!(&block)
      Bind2.setup!(self, &block)
    end

    def <<(previous)
      previous >> self
    end

    def map(&block)
      self >> ::DeferrableGratification.lift(&block)
    end


    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def lift(&block)
        Lift.new(&block)
      end

      def chain(*actions)
        actions.inject(&:>>)
      end
    end
  end
end
