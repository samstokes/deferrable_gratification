# Deferrable Gratification #

## Purpose ##

Deferrable Gratification (DG) makes Ruby Deferrables nicer to work with.

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

Motivating example:

    >> fetcher = AsyncPageFetcher.new('http://samstokes.co.uk')
    >> cv_grepper = fetcher.map(&:response).map {|html| html.grep /CV/ }
    >> cv_grepper.callback {|cv_lines| puts cv_lines }
    >> EM.run { cv_grepper.go }
    checking robots.txt...
    robots.txt missing/unavailable or granted us access
    Fetching url http://samstokes.co.uk ...
    Successful fetch of http://samstokes.co.uk

    <a href="CV/">Click here</a> to view my CV, in MS Word format.
    <p>See <a href="CV/">my CV</a> for a more complete list.</p>
