require 'deferrable_gratification'

describe DeferrableGratification::DefaultDeferrable do
  it_should_behave_like 'a Deferrable'

  it_should_include DeferrableGratification::Combinators
end
