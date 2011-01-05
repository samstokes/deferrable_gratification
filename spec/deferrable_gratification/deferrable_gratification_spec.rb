require 'deferrable_gratification'

require 'eventmachine'
require 'em/deferrable'

describe 'DeferrableGratification.enhance!' do
  class EnhancedDeferrable < EventMachine::DefaultDeferrable
    DG.enhance!(self)
  end

  describe EnhancedDeferrable do
    it_should_include DeferrableGratification::Combinators
  end
end
