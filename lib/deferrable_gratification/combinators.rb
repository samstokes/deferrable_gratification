Dir.glob(File.join(File.dirname(__FILE__), *%w[combinators *.rb])) do |file|
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


    # If this Deferrable fails with a matching exception, it will instead succeed
    # with the return value of the provided block, or nil if no block is given.
    #
    # The parameters to this method are as the parameters to the inbuilt rescue
    # statement. They should be modules that respond true to the {#===} method for
    # exceptions that they wish to catch. The most common example of such
    # modules are subclasses of Exception.
    #
    # If you pass a block to this method then when a matching exception is rescued,
    # the block will be called and the return value of the block will be passed
    # to +Deferrable#succeed+. If you don't pass a block, then {nil} will be
    # used in place of a custom value.
    #
    # @param [Exception Class]  The classes of exception to rescue.
    #
    # @yieldparam exception the exception that matched one of the exception
    #                       classes.
    # @yieldparam *args the remaining arguments passed to the errback when
    #                   this exception was rescued.
    # @yieldreturn value the value with which the deferrable should succeed
    #                    now that the exception has been rescued.
    #
    # @raise [ArgumentError] if called with no exception classes.
    #
    def rescue_from(*to_rescue, &block)
      raise ArgumentError, 'must be called with at least one exception class' if to_rescue.empty?
      errback do |exception, *errback_args|
        begin
          if to_rescue.any?{ |exception_class| exception_class === exception }
            if block
              succeed block.call(exception, *errback_args)
            else
              succeed nil
            end
          end
        rescue => e
          fail(e)
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
      # @param loop_deferrable for internal use only, always omit this.
      # @param &block operation to execute until it succeeds.
      #
      # @yieldreturn [Deferrable] deferred status of the operation.  If it
      #   fails, the operation will be retried.  If it succeeds, the combinator
      #   will succeed with the result.
      #
      # @return [Deferrable] a deferred status that will succeed once the
      #   supplied operation eventually succeeds.
      def loop_until_success(loop_deferrable = DefaultDeferrable.new, &block)
        if EM.reactor_running?
          EM.next_tick do
            begin
              attempt = yield
            rescue => e
              loop_deferrable.fail(e)
            else
              attempt.callback(&loop_deferrable.method(:succeed))
              attempt.errback { loop_until_success(loop_deferrable, &block) }
            end
          end
        else
          # In the synchronous case, we could simply use the same
          # implementation as in EM, but without the next_tick; unfortunately
          # that means direct recursion, so risks stack overflow.  Instead we
          # just reimplement as a loop.
          results = []
          begin
            yield.callback {|*values| results << values } while results.empty?
          rescue => e
            loop_deferrable.fail(e)
          else
            loop_deferrable.succeed(*results[0])
          end
        end
        loop_deferrable
      end
    end
  end
end
