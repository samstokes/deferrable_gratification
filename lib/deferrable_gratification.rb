require File.join(File.dirname(__FILE__), *%w[deferrable_gratification bothback])
require File.join(File.dirname(__FILE__), *%w[deferrable_gratification combinators])
require File.join(File.dirname(__FILE__), *%w[deferrable_gratification default_deferrable])
require File.join(File.dirname(__FILE__), *%w[deferrable_gratification fluent])
require File.join(File.dirname(__FILE__), *%w[deferrable_gratification primitives])

module DeferrableGratification
  # Allow DG.lift, DG.chain etc
  extend Combinators::ClassMethods

  # Allow DG.const, DG.failure etc
  extend Primitives

  # Bestow DG goodness upon an existing module or class.
  #
  # N.B. calling this on a module won't enhance any classes that have already
  # included that module.
  def self.enhance!(module_or_class)
    module_or_class.send :include, Combinators
    module_or_class.send :include, Fluent
    module_or_class.send :include, Bothback
  end

  # Enhance EventMachine::Deferrable itself so that any class including it
  # gets DG goodness.  This should mean that all Deferrables in the current
  # process will get enhanced.
  #
  # N.B. this will not enhance any classes that have *already* included
  # Deferrable before this method was called, so you should call this before
  # loading any other Deferrable libraries, and before defining any of your
  # own Deferrable classes.  (If that isn't possible, you can always call
  # {enhance!} on them after definition.)
  def self.enhance_all_deferrables!
    require 'eventmachine'
    require 'em/deferrable'

    enhance! EventMachine::Deferrable

    # Also have to do that to EM::DefaultDeferrable because it included
    # Deferrable before we enhanced it.
    enhance! EventMachine::DefaultDeferrable
  end

  # Make sure the combinator implementations themselves are enhanced.  Have to
  # do this here, rather than just including the modules in DefaultDeferrable,
  # to avoid a nasty circular dependencies with default_deferrable.rb.
  enhance! DefaultDeferrable
end

# Shorthand
DG = DeferrableGratification
