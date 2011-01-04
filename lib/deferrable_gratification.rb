require File.join(File.dirname(__FILE__), *%w[deferrable_gratification combinators])
require File.join(File.dirname(__FILE__), *%w[deferrable_gratification default_deferrable])
require File.join(File.dirname(__FILE__), *%w[deferrable_gratification primitives])

module DeferrableGratification
  # Make sure the combinator implementations themselves support the combinator
  # operators.  Have to do this here, rather than just including the module in
  # DefaultDeferrable, to avoid a nasty circular dependency between
  # default_deferrable.rb and combinators.rb.
  DefaultDeferrable.send :include, Combinators
end

# Shorthand
DG = DeferrableGratification
