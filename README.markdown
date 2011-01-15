# Deferrable Gratification #

## Purpose ##

Deferrable Gratification (DG) makes evented code less error-prone and easier to
compose, and thus easier to create higher-level abstractions around.  It also
enhances the API offered by Ruby Deferrables to make them more pleasant to work
with.

## Components ##

It currently consists of the following components:

 * [`DG::Fluent`](#fluent): fluent (aka chainable) syntax for registering
   multiple callbacks and errbacks to the same Deferrable.

 * [`DG::Bothback`](#bothback): a `#bothback` method for registering code to
   run on either success or failure.

 * [`DG::Combinators`](#combinators): a combinator library for building up
   complex asynchronous operations out of simpler ones.


<h3 id="fluent"><tt>DG::Fluent</tt></h3>

Use JQuery-style fluent syntax for registering several callbacks and
errbacks on the same Deferrable.  e.g.

     DeferrableMonkeyShaver.new(monkey).
       callback { puts "Monkey is shaved" }.
       callback { monkey.entertain! }.
       errback {|e| puts "Unable to shave monkey! #{e}" }.
       errback {|_| monkey.terminate! }.
       shave

<h3 id="bothback"><tt>DG::Bothback</tt></h3>

Register code to run on either success or failure: shorthand for calling both
`#callback` and `#errback` with the same code block.

<h3 id="combinators"><tt>DG::Combinators</tt></h3>

Allows building up higher-level asynchronous abstractions by composing simpler
asynchronous operations, without having to manually wire callbacks together
and remember to propagate errors correctly.

Motivating example: assume we have an asynchronous database API `DB.query`
which returns a Deferrable to communicate when the query finishes.  (See
the [API docs for `DG::Combinators`](DeferrableGratification/Combinators.html)
for more detail.)

    def product_names_for_username(username)
      DB.query('SELECT id FROM users WHERE username = ?', username).bind! do |user_id|
        DB.query('SELECT name FROM products WHERE user_id = ?', user_id)
      end.map do |product_names|
        product_names.join(', ')
      end
    end
