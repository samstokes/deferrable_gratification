require File.join(File.dirname(__FILE__), *%w[.. default_deferrable])

module DeferrableGratification
  module Combinators
    # Abstract base class for combinators that depend on a number of
    # asynchronous operations (potentially executing in parallel).
    #
    # @abstract Subclasses should override {#done?} to define whether they wait
    #   for some or all of the operations to complete, and {#finish} to define
    #   what they do when {#done?} returns true.
    class Base < DefaultDeferrable
      def initialize
        @successes = []
        @failures = []
      end

      private
      def register_attempt(op)
        index = next_attempt_index

        @successes[index] = Sentinel.new
        @failures[index] = Sentinel.new

        op.callback do |*result|
          @successes[index] = result.first
          finish if done?
        end
        op.errback do |*error|
          @failures[index] = error.first
          finish if done?
        end

        op
      end

      def successes
        without_sentinels(@successes)
      end

      def failures
        without_sentinels(@failures)
      end

      def done?
        raise NotImplementedError, 'subclasses should override this'
      end

      def finish
        raise NotImplementedError, 'subclasses should override this'
      end

      def without_sentinels(ary)
        ary.reject {|item| item.instance_of? Sentinel }
      end

      def next_attempt_index
        @attempt_index = (@attempt_index ? @attempt_index + 1 : 0)
      end

      # @private
      # Used internally to distinguish between the absence of a response and
      # a response with the value +nil+.
      class Sentinel; end
    end
  end
end
