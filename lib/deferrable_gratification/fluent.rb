module DeferrableGratification
  # Allows JQuery-style fluent syntax for registering several callbacks and
  # errbacks on the same Deferrable.  e.g.
  #
  #     DeferrableMonkeyShaver.new(monkey).
  #       callback { puts "Monkey is shaved" }.
  #       callback { monkey.entertain! }.
  #       errback {|e| puts "Unable to shave monkey! #{e}" }.
  #       errback {|_| monkey.terminate! }.
  #       shave
  #
  # Include this into a class that has already included +Deferrable+.
  module Fluent
    # Register +block+ to be called on success.
    #
    # @return [Deferrable, Fluent] +self+
    #
    # @see EventMachine::Deferrable#callback
    def callback(&block)
      super(&block)
      self
    end

    # Register +block+ to be called on failure.
    #
    # @return [Deferrable, Fluent] +self+
    #
    # @see EventMachine::Deferrable#errback
    def errback(&block)
      super(&block)
      self
    end

    # Ensure that if this Deferrable doesn't either succeed or fail within the
    # timeout, it will call its errback with no parameters.
    #
    # @return [Deferrable, Fluent] +self+
    #
    # @see EventMachine::Deferrable#timeout
    def timeout(seconds)
      super(seconds)
      self
    end
  end
end
