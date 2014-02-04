require File.join(File.dirname(__FILE__), *%w[.. default_deferrable])

module DeferrableGratification
  module Combinators
    # Abstract base class for combinators that depend on a number of
    # asynchronous operations (potentially executing in parallel).
    #
    # @abstract Subclasses should override {#done?} to define whether they wait
    #   for some or all of the operations to complete, and {#finish} to define
    #   what they do when {#done?} returns true.
    class Join < Base
      # Prepare to wait for the completion of +operations+.
      #
      # Does not actually set up any callbacks or errbacks: call {#setup!} for
      # that.
      #
      # @param [*Deferrable] *operations deferred statuses of asynchronous
      #   operations to wait for.
      def initialize(*operations)
        super()
        @operations = operations
      end

      # Register callbacks and errbacks on the supplied operations to notify
      # this {Join} of completion.
      def setup!
        finish if done?
        @operations.each &method(:register_attempt)
      end

      # Create a {Join} and register the callbacks.
      #
      # @param (see #initialize)
      #
      # @return [Join] Deferrable representing the join operation.
      def self.setup!(*operations)
        new(*operations).tap(&:setup!)
      end


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
      class Successes < Join
        private
        def done?
          all_completed?
        end

        def finish
          succeed(successes)
        end
      end


      # Combinator that waits for any of the supplied asynchronous operations
      # to succeed, and succeeds with the result of the first (chronologically)
      # to do so.
      #
      # This Deferrable will fail if all the operations fail.  It may never
      # succeed or fail, if one of the operations also does not.
      #
      # You probably want to call {ClassMethods#join_first_success} rather than
      # using this class directly.
      class FirstSuccess < Join
        private
        def done?
          successes.length > 0
        end

        def finish
          succeed(successes.first)
        end
      end

      private

      def all_completed?
        successes.length + failures.length >= @operations.length
      end
    end
  end
end
