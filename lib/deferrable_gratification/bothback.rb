module DeferrableGratification
  # Allows registering a 'bothback' that will be fired on either success or
  # failure, analogous to the +ensure+ clause of a +begin+/+rescue+ block.
  #
  # Include this into a class that has already included +Deferrable+.
  module Bothback
    # Register +block+ to be called on either success or failure.
    # This is just a shorthand for registering the same +block+ as both a
    # callback and an errback.
    #
    # @return [Deferrable, Bothback] +self+
    def bothback(&block)
      callback(&block)
      errback(&block)
      self
    end
  end
end
