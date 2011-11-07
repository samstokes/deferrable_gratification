Dir.glob(File.join(File.dirname(__FILE__), *%w[combinators *.rb])).sort.each do |file|
  require file.sub(/\.rb$/, '')
end

module DeferrableGratification
  # Combinators for building up higher-level asynchronous abstractions by
  # composing simpler asynchronous operations, without having to manually wire
  # callbacks together and remember to propagate errors correctly.
  #
  # @example Perform a sequence of database queries and transform the result.
  #   # With DG::Combinators:
  #   def product_names_for_username(username)
  #     DB.query('SELECT id FROM users WHERE username = ?', username).bind! do |user_id|
  #       DB.query('SELECT name FROM products WHERE user_id = ?', user_id)
  #     end.transform do |product_names|
  #       product_names.join(', ')
  #     end
  #   end
  #
  #   status = product_names_for_username('bob')
  #
  #   status.callback {|product_names| ... }
  #   # If both queries complete successfully, the callback receives the string
  #   # "Car, Spoon, Coffee".  The caller doesn't have to know that two separate
  #   # queries were made, or that the query result needed transforming into the
  #   # desired format: he just gets the event he cares about.
  #
  #   status.errback {|error| puts "Oh no!  #{error}" }
  #   # If either query went wrong, the errback receives the error that occurred.
  #
  #
  #   # Without DG::Combinators:
  #   def product_names_for_username(username)
  #     product_names_status = EM::DefaultDeferrable.new
  #     query1_status = DB.query('SELECT id FROM users WHERE username = ?', username)
  #     query1_status.callback do |user_id|
  #       query2_status = DB.query('SELECT name FROM products WHERE user_id = ?', user_id)
  #       query2_status.callback do |product_names|
  #         product_names = product_names.join(', ')
  #         # N.B. don't forget to report success to the caller!
  #         product_names_status.succeed(product_names)
  #       end
  #       query2_status.errback do |error|
  #         # N.B. don't forget to tell the caller we failed!
  #         product_names_status.fail(error)
  #       end
  #     end
  #     query1_status.errback do |error|
  #       # N.B. don't forget to tell the caller we failed!
  #       product_names_status.fail(error)
  #     end
  #     # oh yes, and don't forget to return this!
  #     product_names_status
  #   end

  module Combinators
    # Alias for {#bind!}.
    #
    # Note that this takes a +Proc+ (e.g. a lambda) while {#bind!} takes a
    # block.
    #
    # @param [Proc] prok proc to call with the successful result of +self+.
    #   Assumed to return a Deferrable representing the status of its own
    #   operation.
    #
    # @return [Deferrable] status of the compound operation of passing the
    #     result of +self+ into the proc.
    #
    # @example Perform a database query that depends on the result of a previous query.
    #   DB.query('first query') >> lambda {|result| DB.query("query with #{result}") }
    def >>(prok)
      Bind.setup!(self, &prok)
    end

    # Register callbacks so that when this Deferrable succeeds, its result
    # will be passed to the block, which is assumed to return another
    # Deferrable representing the status of a second operation.
    #
    # If this operation fails, the block will not be run.  If either operation
    # fails, the compound Deferrable returned will fire its errbacks, meaning
    # callers don't have to know about the inner operations and can just
    # subscribe to the result of {#bind!}.
    #
    #
    # If you find yourself writing lots of nested {#bind!} calls, you can
    # equivalently rewrite them as a chain and remove the nesting: e.g.
    #
    #     a.bind! do |x|
    #       b(x).bind! do |y|
    #         c(y).bind! do |z|
    #           d(z)
    #         end
    #       end
    #     end
    #
    # has the same behaviour as
    #
    #     a.bind! do |x|
    #       b(x)
    #     end.bind! do |y|
    #       c(y)
    #     end.bind! do |z|
    #       d(y)
    #     end
    #
    # As well as being more readable due to avoiding left margin inflation,
    # this prevents introducing bugs due to inadvertent local variable capture
    # by the nested blocks.
    #
    #
    # @see #>>
    #
    # @param &block block to call with the successful result of +self+.
    #   Assumed to return a Deferrable representing the status of its own
    #   operation.
    #
    # @return [Deferrable] status of the compound operation of passing the
    #     result of +self+ into the block.
    #
    # @example Perform a web request based on the result of a database query.
    #   DB.query('url').bind! {|url| HTTP.get(url) }.
    #     callback {|response| puts "Got response!" }
    def bind!(&block)
      Bind.setup!(self, &block)
    end

    # Transform the result of this Deferrable by invoking +block+, returning
    # a Deferrable which succeeds with the transformed result.
    #
    # If this operation fails, the operation will not be run, and the returned
    # Deferrable will also fail.
    #
    # @param &block block that transforms the expected result of this
    #   operation in some way.
    #
    # @return [Deferrable] Deferrable that will succeed if this operation did,
    #   after transforming its result.
    #
    # @example Retrieve a web page and call back with its title.
    #   HTTP.request(url).transform {|page| Hpricot(page).at(:title).inner_html }
    def transform(&block)
      Bind.setup!(self, :without_chaining => true, &block)
    end

    # Transform the value passed to the errback of this Deferrable by invoking
    # +block+.  If this operation succeeds, the returned Deferrable will
    # succeed with the same value.  If this operation fails, the returned
    # Deferrable will fail with the transformed error value.
    #
    # @param &block block that transforms the expected error value of this
    #   operation in some way.
    #
    # @return [Deferrable] Deferrable that will succeed if this operation did,
    #   otherwise fail after transforming the error value with which this
    #   operation failed.
    def transform_error(&block)
      errback do |*err|
        self.fail(
          begin
            yield(*err)
          rescue => e
            e
          end)
      end
    end


    # If this Deferrable succeeds, ensure that the arguments passed to
    # +Deferrable#succeed+ meet certain criteria (specified by passing a
    # predicate as a block).  If they do, subsequently defined callbacks will
    # fire as normal, receiving the same arguments; if they do not, this
    # Deferrable will fail instead, calling its errbacks with a {GuardFailed}
    # exception.
    #
    # This follows the usual Deferrable semantics of calling +Deferrable#fail+
    # inside a callback: any callbacks defined *before* the call to {#guard}
    # will still execute as normal, but those defined *after* the call to
    # {#guard} will only execute if the predicate returns truthy.
    #
    # Multiple successive calls to {#guard} will work as expected: the
    # predicates will be evaluated in order, stopping as soon as any of them
    # returns falsy, and subsequent callbacks will fire only if all the
    # predicates pass.
    #
    # If instead of returning a boolean, the predicate raises an exception,
    # the Deferrable will fail, but errbacks will receive the exception raised
    # instead of {GuardFailed}.  You could use this to indicate the reason for
    # failure in a complex guard expression; however the same intent might be
    # more clearly expressed by multiple guard expressions with appropriate
    # reason messages.
    #
    # @param [String] reason optional description of the reason for the guard:
    #                        specifying this will both serve as code
    #                        documentation, and be included in the
    #                        {GuardFailed} exception for error handling
    #                        purposes.
    #
    # @yieldparam *args the arguments passed to callbacks if this Deferrable
    #                   succeeds.
    # @yieldreturn [Boolean] +true+ if subsequent callbacks should fire (with
    #                        the same arguments); +false+ if instead errbacks
    #                        should fire.
    #
    # @raise [ArgumentError] if called without a predicate
    def guard(reason = nil, &block)
      raise ArgumentError, 'must be called with a block' unless block_given?
      callback do |*callback_args|
        begin
          unless block.call(*callback_args)
            raise ::DeferrableGratification::GuardFailed.new(reason, callback_args)
          end
        rescue => exception
          fail(exception)
        end
      end
      self
    end


    # Boilerplate hook to extend {ClassMethods}.
    def self.included(base)
      base.send :extend, ClassMethods
    end

    # Combinators which don't make sense as methods on +Deferrable+.
    #
    # {DeferrableGratification} extends this module, and thus the methods
    # here are accessible via the {DG} alias.
    module ClassMethods
      # Execute a sequence of asynchronous operations that may each depend on
      # the result of the previous operation.
      #
      # @see #bind! more detail on the semantics.
      #
      # @param [*Proc] *actions procs that will perform an operation and
      #   return a Deferrable.
      #
      # @return [Deferrable] Deferrable that will succeed if all of the
      #   chained operations succeeded, and callback with the result of the
      #   last operation.
      def chain(*actions)
        actions.inject(DG.const(nil), &:>>)
      end

      # Combinator that waits for all of the supplied asynchronous operations
      # to succeed or fail, then succeeds with the results of all those
      # operations that were successful.
      #
      # This Deferrable will never fail.  It may also never succeed, if _any_
      # of the supplied operations does not either succeed or fail.
      #
      # The successful results are guaranteed to be in the same order as the
      # operations were passed in (which may _not_ be the same as the
      # chronological order in which they succeeded).
      #
      # @param [*Deferrable] *operations deferred statuses of asynchronous
      #   operations to wait for.
      #
      # @return [Deferrable] a deferred status that will succeed after all the
      #   +operations+ have either succeeded or failed; its callbacks will be
      #   passed an +Enumerable+ containing the results of those operations
      #   that succeeded.
      def join_successes(*operations)
        Join::Successes.setup!(*operations)
      end

      # Combinator that waits for any of the supplied asynchronous operations
      # to succeed, and succeeds with the result of the first (chronologically)
      # to do so.
      #
      # This Deferrable will fail if all the operations fail.  It may never
      # succeed or fail, if one of the operations also does not.
      #
      # @param (see #join_successes)
      #
      # @return [Deferrable] a deferred status that will succeed as soon as any
      #   of the +operations+ succeeds; its callbacks will be passed the result
      #   of that operation.
      def join_first_success(*operations)
        Join::FirstSuccess.setup!(*operations)
      end

      # Combinator that repeatedly executes the supplied block until it
      # succeeds, then succeeds itself with the eventual result.
      #
      # This Deferrable may never succeed, if the operation never succeeds.
      # It will fail if an iteration raises an exception.
      #
      # @note this combinator is intended for use inside EventMachine.  It will
      #   still work outside of EventMachine, _provided_ that the operation is
      #   synchronous (although a simple +while+ loop might be preferable in
      #   this case!).
      #
      # @param &block operation to execute until it succeeds.
      #
      # @yieldreturn [Deferrable] deferred status of the operation.  If it
      #   fails, the operation will be retried.  If it succeeds, the combinator
      #   will succeed with the result.
      #
      # @return [Deferrable] a deferred status that will succeed once the
      #   supplied operation eventually succeeds.
      def loop_until_success(&block)
        Combinators::Loop::UntilSuccess.setup!(&block)
      end

      # Combinator that repeatedly executes the supplied block until it
      # fails, then fails itself with the eventual error.
      #
      # This Deferrable may never fail, if the operation never fails.
      #
      # This combinator has similar semantics to the inbuilt +loop+ construct,
      # in that you need to do something drastic to break out of the loop.
      #
      # If you want to stop the loop early, you can call {#succeed} or {#fail}
      # on the returned deferrable.
      #
      # @note this combinator is intended for use inside EventMachine.  It will
      #   still work outside of EventMachine, _provided_ that the operation is
      #   synchronous (although a simple +while+ loop might be preferable in
      #   this case!).
      #
      # @param &block operation to execute until it fails.
      #
      # @yieldreturn [Deferrable] deferred status of the operation.  If it
      #   succeeds, the operation will be retried.  If it fails, the combinator
      #   will fail with the result.
      #
      # @return [Deferrable] a deferred status that will fail once the
      #   supplied operation eventually fails.
      def loop_until_failure(&block)
        Combinators::Loop::UntilFailure.setup!(&block)
      end

      # Combinator that repeatedly calls the supplied condition followed by the
      # supplied block until either the condition returns a falsey value or
      # the block fails.
      #
      # In other words, this is an asynchonous version of the Ruby {while} loop.
      #
      # Failure can occur if either the condition or the block raise an
      # exception, or if the deferrable returned by the block fails.
      #
      # @note this combinator is intended for use inside EventMachine.  It will
      #   still work outside of EventMachine, _provided_ that the operation is
      #   synchronous (although a simple +while+ loop might be preferable in
      #   this case!).
      #
      # @param [Proc, Method, #===] condition returns truthy if the loop should
      #   continue.
      #
      # @callparam [*Object, nil] the result with which the previous execution of
      #   the block succeeded, or nil on the first call.
      #
      # @param [&Block] block operation to execute until it fails.
      #
      # @yieldreturn [Deferrable] deferred status of the operation. If it
      #   succeeds, the condition will be executed again.  If it fails, the
      #   combinator will fail with the result.
      #
      # @return [Deferrable] a deferred status that will succeed when the
      #   condition returns falsey with the success value of the most recently
      #   executed deferrable returned by the block.
      #
      # @see {#loop_until}
      #
      def loop_while(condition, &block)
        Combinators::Loop::While.setup!(condition, &block)
      end

      # Combinator that repeatedly calls the supplied condition followed by the
      # supplied block until either the condition returns a truthy value or the
      # block fails.
      #
      # In other words, this is an asynchornous version of the Ruby {until}
      # loop.
      #
      # @note this combinator is intended for use inside EventMachine.  It will
      #   still work outside of EventMachine, _provided_ that the operation is
      #   synchronous (although a simple +while+ loop might be preferable in
      #   this case!).
      #
      # @param [Proc, Method, #===] condition returns truthy if the loop should
      #   stop.
      #
      # @callparam [*Object, nil] the result with which the previous execution of
      #   the block succeeded, or nil on the first call.
      #
      # @param [&Block] block operation to execute until it fails.
      #
      # @yieldreturn [Deferrable] deferred status of the operation. If it
      #   succeeds, the condition will be executed again.  If it fails, the
      #   combinator will fail with the result.
      #
      # @return [Deferrable] a deferred status that will succeed when the
      #   condition returns truthy with the success value of the most recently
      #   executed deferrable returned by the block.
      #
      # @see {#loop_while}
      #
      def loop_until(condition, &block)
        loop_while(lambda{ |*args| !condition.call *args }, &block)
      end
    end
  end
end
