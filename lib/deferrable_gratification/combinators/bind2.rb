require File.join(File.dirname(__FILE__), *%w[.. default_deferrable])

module DeferrableGratification
  module Combinators
    class Bind2 < DefaultDeferrable
      def initialize(first, &block)
        @first = first

        raise ArgumentError, 'must pass a block' unless block
        @proc = block
      end

      def setup!
        @first.callback {|*args| @proc.call(*args) rescue nil }
      end

      def self.setup!(*args, &block)
        new(*args, &block).tap(&:setup!)
      end
    end
  end
end
