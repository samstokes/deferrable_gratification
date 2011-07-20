require File.join(File.dirname(__FILE__), *%w[.. default_deferrable])

module DeferrableGratification
  module Combinators
    # Combinator that passes the result of one deferred operation to a block
    # that uses that result to begin another deferred operation.  The compound
    # operation itself succeeds if the second operation does.
    #
    # You probably want to call {#bind!} rather than using this class directly.
    #
    # If we define +Deferrable err (IO a)+ to be the type of a Deferrable that
    # may perform a side effect and then either succeed with a value of type a
    # or fail with an error of type err, then we expect the block to have type
    #
    #     a -> Deferrable err (IO b)
    #
    # and if so this combinator (actually {Bind.setup!}) is a specialisation
    # of the monadic bind operator +>>=+:
    #
    #     # example: database query that depends on the result of another
    #     Bind.setup!(DB.query('select foo from bar')) do |result|
    #       DB.query("select baz from quuz where name = '#{result}'")
    #     end
    #
    #     # type signatures, in pseudo-Haskell
    #     (>>=) :: Deferrable err a ->
    #                  (a -> Deferrable err b) -> Deferrable err b
    #     Bind :: Deferrable err a ->
    #                  (a -> Deferrable err (IO b)) -> Deferrable err (IO b)
    #
    # However, because Ruby doesn't actually type-check blocks, we can't
    # enforce that the block really does return a second Deferrable.  This
    # therefore also supports (reasonably) arbitrary blocks.  However, it's
    # probably clearer (though equivalent) to use {#transform} for this case.
    class Bind < DefaultDeferrable
      # Prepare to bind +block+ to +first+, and create the Deferrable that
      # will represent the bind.
      #
      # Does not actually set up any callbacks or errbacks: call {#setup!} for
      # that.
      #
      # @param [Deferrable] first  operation to bind to.
      # @param &block  block to run on success; should return a Deferrable.
      #
      # @raise [ArgumentError] if called without a block.
      def initialize(first, options = {}, &block)
        @first = first

        @with_chaining = !options.delete(:without_chaining)
        bad_keys = options.keys.join(', ')
        raise "Unknown options: #{bad_keys}" unless bad_keys.empty?

        raise ArgumentError, 'must pass a block' unless block
        @proc = block
      end

      # Register a callback on the first Deferrable to run the bound block on
      # success, and an errback to fail this {Bind} on failure.
      def setup!
        @first.callback {|*args| run_bound_proc(*args) }
        @first.errback {|*args| self.fail(*args) }
      end

      # Create a {Bind} and register the callbacks.
      #
      # @param (see #initialize)
      #
      # @return [Bind] Deferrable representing the compound operation.
      #
      # @raise (see #initialize)
      def self.setup!(first, options = {}, &block)
        new(first, options, &block).tap(&:setup!)
      end

      private
      def run_bound_proc(*args)
        begin
          second = @proc.call(*args)
        rescue => error
          self.fail(error)
        else
          # We expect the block to return a Deferrable, on which we can set
          # callbacks.  However, as referred to in the class comment above, we
          # can't assume that it will, and need to behave sensibly if it
          # doesn't.
          if @with_chaining && second.respond_to?(:callback) && second.respond_to?(:errback)
            second.callback {|*args2| self.succeed(*args2) }
            second.errback {|*error| self.fail(*error) }
          else
            # Not a Deferrable, so we need to "behave sensibly" as alluded to
            # above.  Just behaving like #transform is sensible enough.
            self.succeed(second)
          end
        end
      end
    end
  end
end
