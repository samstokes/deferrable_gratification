require 'eventmachine'
require 'em/deferrable'

module DeferrableGratification
  # Barebones Deferrable that includes the {DeferrableGratification}
  # extensions:
  #
  # @see Fluent
  # @see Bothback
  # @see Combinators
  class DefaultDeferrable
    include EventMachine::Deferrable

    # want to include Combinators here, but that would introduce a circular
    # dependency, so have to do that in the top-level .rb file.
  end
end
