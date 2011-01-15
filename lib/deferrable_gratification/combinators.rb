Dir.glob(File.join(File.dirname(__FILE__), *%w[combinators *.rb])) do |file|
  require file.sub(/\.rb$/, '')
end

module DeferrableGratification
  module Combinators
    def >>(prok)
      Bind.setup!(self, &prok)
    end

    def bind!(&block)
      Bind.setup!(self, &block)
    end

    def map(&block)
      bind!(&block)
    end


    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def chain(*actions)
        actions.inject(DG.const(nil), &:>>)
      end
    end
  end
end
