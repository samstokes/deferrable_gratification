# Deferrable Gratification #

Deferrable Gratification (DG) facilitates asynchronous programming in Ruby, by
helping create abstractions around complex operations built up from simpler
ones.  It helps make asynchronous code less error-prone and easier to compose.
It also provides some enhancements to the
[`Deferrable`](http://eventmachine.rubyforge.org/EventMachine/Deferrable.html)
API.

## Motivation ##

Asynchronous programming, as supported in Ruby by
[EventMachine](http://rubyeventmachine.com/), offers the benefits of (limited)
concurrency without the complexity of threads.  However, it requires a style of
code that fits awkwardly into Ruby's synchronous semantics.

A method that performs an asynchronous operation cannot simply return a result:
instead it must take a callback, which it calls with the eventual result of the
operation.  That method's caller must also now take a callback, and so on up
the call chain.  This means replacing a synchronous library such as
[Net::HTTP](http://ruby-doc.org/stdlib-1.8.7/libdoc/net/http/rdoc/index.html)
with an asynchronous library such as
[em-http-request](https://github.com/igrigorik/em-http-request) can require
rewriting a surprisingly large part of a codebase.

Ruby's block syntax initially seems to support this callback-passing style
well.

    asynchronously_fetch_page do |page|
      # do something with 'page'...
    end

The first problem is that, unlike regular method parameters, Ruby doesn't check
that the caller remembered to provide a block, making it easy to create bugs by
forgetting a callback.

    page = asynchronously_fetch_page
    # returns immediately with no error.  'page' is probably nil.

Similarly the method implementer may forget to pass the callback down to nested
calls, which can render the whole chain of asynchronous methods unable to
return a result.  (The asynchronous operation might itself check that a
callback was given, but asynchronous libraries will often not require a
callback, in case they were invoked only for their side-effects.)

    def first_thing(&callback)
      second_thing(&callback)
    end
    def second_thing(&callback)
      third_thing    # oops! no error though.
    end
    def third_thing(&callback)
      compute_answer
      yield 42 if block_given?
    end

    first_thing {|answer| puts answer }     # never runs

This is a symptom of a more general problem: only the outermost caller really
cares about the callback being run, yet every method in the chain must be aware
of it, which is poor encapsulation.

This style also breaks down when the asynchronous operation needs to
communicate failure: we want to pass in some code to be called on error, but
Ruby's syntax only allows passing a single block to a method, so callers now
need to pass in `lambda`s or hashes of `Proc`s, the syntax becomes inconsistent
and noisy, and readability and maintainability suffer:

    def first_thing(errback, &callback)
      do_something
      yield if block_given? # as declared, callback is implicitly optional
    rescue => e
      errback.call(e)       # as declared, errback is mandatory
    end

    # Excessive punctuation alert!
    first_thing(lambda {|error| handle_error }) {|result| use_result(result) }

EventMachine offers the
[Deferrable](http://eventmachine.rubyforge.org/EventMachine/Deferrable.html)
pattern to communicate results of asynchronous operations in an object-oriented
style more natural to Ruby.  Rather than taking a callback which it must
remember to call, the method simply returns a `Deferrable` object which
encapsulates the status of the operation, and promises to update that object at
a later date.  Callers can register callbacks and errbacks on the Deferrable,
which takes care of calling them when the operation succeeds or fails.
Intermediate methods in the chain can simply pass the Deferrable on, and only
code which cares about callbacks need know about them.

However, asynchronous programming with Deferrables still suffers from two key
problems: it is difficult to compose multiple operations, and to build up
complex operations from simpler ones.  Below is a method which performs three
synchronous operations in sequence, each depending on the result of the
previous, and returns the result of the last operation to the caller:

    def complex_operation
      first_result = do_first_thing
      second_result = do_second_thing(first_result)
      third_result = do_third_thing(second_result)
      third_result
    rescue => e
      # ...
    end

When the operations are asynchronous, the same sequence is typically
implemented using nested callbacks:

    def complex_operation
      result = EM::DefaultDeferrable.new
      first_deferrable = do_first_thing
      first_deferrable.callback do |first_result|
        second_deferrable = do_second_thing(first_result)
        second_deferrable.callback do |second_result|
          third_deferrable = do_third_thing(second_result)
          third_deferrable.callback do |third_result|
            result.succeed(third_result)
          end
          third_deferrable.errback do |third_error|
            result.fail(third_error)
          end
        end
        second_deferrable.errback do |second_error|
          result.fail(second_error)
        end
      end
      first_deferrable.errback do |first_error|
        result.fail(first_error)
      end
      result
    end

Like the synchronous version, this method abstracts the multiple operations
away from the caller and presents only the result the caller was interested in
(or details of what went wrong).  However, the line count has tripled.  Worse,
the program flow is confusing: the logic of 'do these operations in sequence'
is obscured; the errbacks read in reverse order; and the way the final result
makes its way back to the caller is almost invisible.  There are also a lot of
opportunities to create bugs: all of the callbacks must be manually and
repetitively "wired together", or the method will not work.

Deferrable Gratification aims to solve these problems by providing a library of
composition operators - combinators - which abstract away the boilerplate
callback wiring and reveal the logic of the code.

## Getting started ##

Install the gem:

    gem install deferrable_gratification

In your code:

    require 'eventmachine'
    require 'deferrable_gratification'
    DG.enhance_all_deferrables!

Make sure that the call to
[DG.enhance_all_deferrables!](http://samstokes.github.com/deferrable_gratification/doc/DeferrableGratification.html#enhance_all_deferrables%21-class_method)
comes *before* you require any library that uses `Deferrable` (e.g.
[em-http-request](https://github.com/igrigorik/em-http-request)).

## Documentation ##

* [API](http://samstokes.github.com/deferrable_gratification/doc/frames.html)
* [Behaviour specs](http://samstokes.github.com/deferrable_gratification/doc/spec/index.html)
  (generated from RSpec code examples)

## Structure ##

It currently consists of the following modules:

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
the [API docs for `DG::Combinators`](http://samstokes.github.com/deferrable_gratification/doc/DeferrableGratification/Combinators.html)
for more detail.)

    def product_names_for_username(username)
      DB.query('SELECT id FROM users WHERE username = ?', username).bind! do |user_id|
        DB.query('SELECT name FROM products WHERE user_id = ?', user_id)
      end.transform do |product_names|
        product_names.join(', ')
      end
    end
