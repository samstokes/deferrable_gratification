module DeferrableGratification
  module Combinators
    # Abstract base class for combinators that depend on a number of
    # asynchronous operations executing sequentially.
    #
    # @abstract Subclasses should override {#done?} to define whether they wait
    #   for some or all of the operations to complete, and {#finish} to define
    #   what they do when {#done?} returns true.
    class Loop < Base

      # Prepare to loop over deferrables  yielded by +block+
      #
      # Does not actually set up any callbacks or errbacks: call {#setup!} for
      # that.
      #
      # @param [&Block] A block to lazily yield deferrables.
      #
      # @yieldreturn Deferrable
      def initialize(&block)
        super()
        @block = block
      end

      # Fetch the first deferrable and set up callbacks and errbacks such that
      # we'll continue iterating.
      #
      # When running in EventMachine we insert a next tick around each operation
      # so that the resulting deferrable is guaranteed to be asynchronous.
      #
      # When not running in EventMachine we flatten the loop into a while loop
      # to prevent a StackOverflowException
      def setup!
        finish if done?

        # When the outer deferrable is stopped, we explicitly stop the loop.
        bothback{ @stopped = true }

        if EM::reactor_running?
          on_next_tick
        else
          until stopped?
            next_attempt
          end
        end
      end

      # Create a {Loop} and register the callbacks.
      #
      # @param (see #initialize)
      #
      # @return [Join] Deferrable representing the join operation.
      def self.setup!(*args, &block)
        new(*args, &block).tap &:setup!
      end

      private

      def on_next_tick
        EM::next_tick do
          if !stopped? && attempt = next_attempt
            attempt.callback{ on_next_tick }
            attempt.errback{ on_next_tick }
          end
        end
      end

      def next_attempt
        register_attempt @block.call
      rescue => e
        fail e
        return false
      end

      def stopped?; !!@stopped; end

      # Combinator that runs each deferrable yielded by a block sequentially
      # until one of them succeeds, then succeeds with the result of the
      # successful operation.
      #
      # This Deferrable will fail if the block raises an exception directly, and
      # may never succeed if the block continues to return failing deferrables.
      #
      # You probably want to call {ClassMethods#loop_until_success} rather than
      # using this class directly.
      class UntilSuccess < Loop
        private
        def done?
          successes.length > 0
        end

        def finish
          succeed(successes.first)
        end
      end

      # Combinator that runs each deferrable yielded by a block sequentially
      # until one of them fails, then fails with the resulting error.
      #
      # This Deferrable will fail if the block raises an exception directly, and,
      # like a while loop, # may never fail if the block continues to succeed.
      #
      # You probably want to call {ClassMethods#loop_until_failure} rather than
      # using this class directly.
      class UntilFailure < Loop
        private
        def done?
          failures.length > 0
        end

        def finish
          fail(failures.first)
        end
      end

      # Combinator that runs the condition lambda and then the provided block
      # sequentially until either the condition lambda returns true, or an
      # exception is raised, or the provided block returns a deferrable that
      # fails.
      #
      # This is, in other words, a normal ruby "while" loop, except that the
      # body of the loop sets up a deferrable which runs asynchronously instead
      # of requiring that the whole operation is synchronous.
      #
      # You probably want to call {ClassMethods#loop_while} or
      # {ClassMethods#loop_until} rather than using this class directly.
      class While < Loop
        # Prepare to loop over deferrables yielded by +block+, stopping when
        # +condition+ returns a truthy value.
        #
        # Does not actually set up any callbacks or errbacks: call {#setup!} for
        # that.
        #
        # @param [Proc, Method, #call] A condition that returns truthy when the
        #                              loop should stop.
        # @param [&Block] A block to lazily yield deferrables.
        #
        # @yieldreturn Deferrable
        def initialize(condition, &block)
          raise ArgumentError, "condition must be callable" unless condition.respond_to?(:call)
          raise ArgumentError, "no loop body given" unless block_given?
          @condition = condition
          super &block
        end

        private
        def done?
          failures.length > 0 || !@condition.call(successes.last)
        rescue => e
          fail e
        end

        def finish
          if failures.length > 0
            fail failures.last
          else
            succeed successes.last
          end
        end
      end
    end
  end
end

