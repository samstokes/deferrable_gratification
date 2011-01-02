require File.join(File.dirname(__FILE__), *%w[em deferrable combinators])
require File.join(File.dirname(__FILE__), *%w[em deferrable combinator_operators])

# Make sure the combinator implementations themselves support the combinator
# operators.  Have to do this here, rather than just including the module
# in the combinator classes, to avoid a nasty circular dependency between
# combinators.rb and combinator_operators.rb.
%w(Bind).each do |combinator|
  klazz = EventMachine::Deferrable::Combinators.const_get(combinator)
  klazz.send :include, EventMachine::Deferrable::CombinatorOperators
end
