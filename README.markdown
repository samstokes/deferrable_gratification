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

## Examples ##

### [`bothback`](http://samstokes.github.com/deferrable\_gratification/doc/DeferrableGratification/Bothback.html#bothback-instance\_method): when you absolutely, positively got to... ###

Sometimes you need to do something after an asynchronous action completes,
whether it succeeded or failed: e.g. release a lock, or as in the example
above, call `EM.stop` to break out of the `EM.run` block.  It's annoying to
have to write that code twice, to make sure it's called both on success and
failure.

`bothback` to the rescue:

    EM.run { google_homepage.bothback { EM.stop } }
    # prints a lot of HTML

### [`transform`](http://samstokes.github.com/deferrable\_gratification/doc/DeferrableGratification/Combinators.html#transform-instance\_method): receive the callbacks that make sense for you ###

The [em-http-request](https://github.com/igrigorik/em-http-request) library is
great, but it's a bit fiddly to use, because it passes the whole
[`EM::HttpClient`](http://rdoc.info/github/igrigorik/em-http-request/master/EventMachine/HttpClient)
instance to its callbacks and errbacks.  That means your callbacks can check
the response code and headers, but it also makes it harder if you just want
quick access to the response body.

    EM.run do
      request = EM::HttpRequest.new('http://google.com').get(:redirects => 1)
      request.
        callback do |http|
          # Have to write this code once for each different request
          if http.response_header.status == 200
            puts http.response
          else
            request.fail(http)   # triggers the errback as if the request had failed
          end
        end.errback {|http| handle_error(http) }.
        bothback { EM.stop }
    end
    # prints lots of HTML

Wouldn't it be great if we could encapsulate the logic of "just give me the
response if the request was successful", and have callbacks that just act on
the response body?

    def fetch_page(url)
      request = EM::HttpRequest.new(url).get(:redirects => 1)
      request.transform do |http|
        if http.response_header.status == 200
          http.response
        else
          request.fail(http)
        end
      end
    end

    EM.run do
      fetch_page('http://google.com').
        callback {|html| puts html }.
        errback {|http| puts "Oh dear!" }.
        bothback { EM.stop }
    end
    # prints lots of HTML

That looks a lot cleaner.  It would be even cooler if instead of passing the
raw HTML to callbacks, we could parse the HTML using
[Hpricot](http://hpricot.com) and pass the parsed document instead.  No
problem:

    require 'hpricot'

    def fetchpricot(url)
      fetch_page(url).transform {|html| Hpricot(html) }
    end

    EM.run do
      fetchpricot('http://google.com').
        callback {|doc| puts doc.at(:title) }.
        errback {|http| puts "Oh dear!" }.
        bothback { EM.stop }
    end
    # prints <title>Google</title>

### [`transform_error`](http://samstokes.github.com/deferrable\_gratification/doc/DeferrableGratification/Combinators.html#transform_error-instance\_method): receive the errbacks that make sense to you ###

That's cool, but it's a bit annoying that those errbacks receive a `HttpClient`
object - we have to turn that into a useful error message every time.  Let's
encapsulate that too:

    def fetchpricot2(url)
      fetchpricot(url).transform_error do |http|
        if http.response_header.status > 0
          "Unexpected response code: #{http.response_header.status}"
        else
          "Unknown error!"
        end
      end
    end

    EM.run do
      fetchpricot2('http://google.com/page_that_probably_does_not_exist').
        callback {|doc| puts doc.at(:title) }.
        errback {|error| puts "Error: #{error}" }.
        bothback { EM.stop }
    end
    # prints "Error: Unexpected response code: 404"

### [`bind!`](http://samstokes.github.com/deferrable\_gratification/doc/DeferrableGratification/Combinators.html#bind!-instance\_method): for when one thing leads to another ###

Say we want to do a simple web crawling task: find the first search result for
'deferrable_gratification', follow that link (which should be its Github page),
and pull down the project website listed on that page.  Normally this would
require some messy nesting of callbacks and errbacks:

    EM.run do
      fetchpricot2('http://google.com/search?q=deferrable_gratification').callback do |doc1|
        fetchpricot2((doc1 / 'ol' / 'li' / 'a')[0][:href]).callback do |doc2|
          fetchpricot2((doc2 / '#repository_homepage').at(:a)[:href]).callback do |doc3|
            puts doc3.at(:title).inner_text
            # I could also have mistyped 'doc3' as 'doc2' and got the wrong
            # behaviour, but no exception to flag it
          end.errback do |error|
            puts "Error finding homepage link: #{error}"
          end.bothback { EM.stop }
        end.errback do |error|
          puts "Error loading first search result: #{error}"
          EM.stop
        end
      end.errback do |error|
        puts "Error retrieving search results: #{error}"
        EM.stop
      end
    end
    # prints "Deferrable Gratification"

With `Deferrable#bind!` we can remove the nesting and write something that
looks more like the straight-line sequential flow:

    EM.run do
      fetchpricot2('http://google.com/search?q=deferrable_gratification').bind! do |doc|
        fetchpricot2((doc / 'ol' / 'li' / 'a')[0][:href])
      end.bind! do |doc|
        fetchpricot2((doc / '#repository_homepage').at(:a)[:href])
      end.callback do |doc|
        puts doc.at(:title).inner_text
        # now the previous 'doc's aren't in scope, so I can't accidentally
        # refer to them
      end.errback do |error|
        puts "Error: #{error}"
      end.bothback { EM.stop }
    end
    # prints "Deferrable Gratification"

`bind!` also wires up the errbacks so we can just write a single errback that
will fire if any step in the sequence fails; similarly we don't have to write
`EM.stop` three times.

## Getting started ##

Install the gem:

    gem install deferrable_gratification

In your code:

    require 'eventmachine'
    require 'deferrable_gratification'
    DG.enhance_all_deferrables!

Make sure that the call to
[`DG.enhance_all_deferrables!`](http://samstokes.github.com/deferrable_gratification/doc/DeferrableGratification.html#enhance_all_deferrables%21-class_method)
comes *before* you require any library that uses `Deferrable` (e.g.
[em-http-request](https://github.com/igrigorik/em-http-request)).

### Temporary workaround because `enhance_all_deferrables!` is broken ###

You actually need to call
[`DG.enhance!`](http://samstokes.github.com/deferrable_gratification/doc/DeferrableGratification.html#enhance%21-class_method)
on each Deferrable class you'll be dealing with. This call needs to come
*after* that class is defined.

## Documentation ##

* [API](http://samstokes.github.com/deferrable_gratification/doc/frames.html)
* [Behaviour specs](http://samstokes.github.com/deferrable_gratification/doc/spec/index.html)
  (generated from RSpec code examples)
