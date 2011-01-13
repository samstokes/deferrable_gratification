require File.join(File.dirname(__FILE__), *%w[.. default_deferrable])

module DeferrableGratification
  module Combinators
    # If we define 'Deferrable err a' to be the type of a Deferrable that may
    # succeed with a value of type a or fail with an error of type err, then
    # Bind2.setup! is a specialisation of the monadic >>=:
    #
    # (>>=) :: Deferrable err a -> (a -> Deferrable err b) -> Deferrable err b
    # Bind2.setup! :: Deferrable err a -> (a -> Deferrable err (IO b)) -> Deferrable err (IO b)
    #
    # Where Deferrable err (IO b) means a Deferrable that may perform a side
    # effect and then succeed with a value of type b or fail with a value of
    # type err.
    class Bind2 < DefaultDeferrable
      def initialize(first, &block)
        @first = first

        raise ArgumentError, 'must pass a block' unless block
        @proc = block
      end

      def setup!
        @first.callback do |*args|
          @proc.call(*args).tap do |second|
            second.callback {|*args2| self.succeed(*args2) }
            second.errback {|*error| self.fail(*error) }
          end rescue nil
        end
        @first.errback {|*args| self.fail(*args) }
      end

      def self.setup!(*args, &block)
        new(*args, &block).tap(&:setup!)
      end
    end
  end
end
