require File.join(File.dirname(__FILE__), *%w[deferrable_gratification combinators])
require File.join(File.dirname(__FILE__), *%w[deferrable_gratification combinator_operators])
require File.join(File.dirname(__FILE__), *%w[deferrable_gratification default_deferrable])

module DeferrableGratification
  # Make sure the combinator implementations themselves support the combinator
  # operators.  Have to do this here, rather than just including the module in
  # DefaultDeferrable, to avoid a nasty circular dependency between
  # default_deferrable.rb and combinator_operators.rb.
  DefaultDeferrable.send :include, CombinatorOperators
end

# Shorthand
DG = DeferrableGratification
