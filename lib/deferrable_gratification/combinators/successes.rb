require File.join(File.dirname(__FILE__), *%w[.. default_deferrable])

module DeferrableGratification
  module Combinators
    # Combinator that waits for all of the supplied asynchronous operations
    # to succeed or fail, then succeeds with the results of all those
    # operations that were successful.
    #
    # This Deferrable will never fail.  It may also never succeed, if _any_
    # of the supplied operations does not either succeed or fail.
    #
    # The successful results are guaranteed to be in the same order as the
    # operations were passed in (which may _not_ be the same as the
    # chronological order in which they succeeded).
    #
    # You probably want to call {ClassMethods#join_successes} rather than
    # using this class directly.
    class Successes < DefaultDeferrable
      # Prepare to wait for the completion of +operations+.
      #
      # Does not actually set up any callbacks or errbacks: call {#setup!} for
      # that.
      #
      # @param [*Deferrable] *operations deferred statuses of asynchronous
      #   operations to wait for.
      def initialize(*operations)
        @operations = operations
        @successes = Array.new(@operations.size, Sentinel.new)
        @failures = Array.new(@operations.size, Sentinel.new)
      end

      # Register callbacks and errbacks on the supplied operations to notify
      # this {Successes} of completion.
      def setup!
        finish if done?

        @operations.each_with_index do |op, index|
          op.callback do |result|
            @successes[index] = result
            finish if done?
          end
          op.errback do |error|
            @failures[index] = error
            finish if done?
          end
        end
      end

      # Create a {Successes} and register the callbacks.
      #
      # @param (see #initialize)
      #
      # @return [Successes] Deferrable representing the join operation.
      def self.setup!(*operations)
        new(*operations).tap(&:setup!)
      end

      private
      def successes
        without_sentinels(@successes)
      end

      def failures
        without_sentinels(@failures)
      end

      def without_sentinels(ary)
        ary.reject {|item| item.instance_of? Sentinel }
      end

      def done?
        successes.length + failures.length >= @operations.length
      end

      def finish
        succeed(successes)
      end

      # @private
      # Used internally to distinguish between the absence of a response and
      # a response with the value +nil+.
      class Sentinel; end
    end
  end
end
