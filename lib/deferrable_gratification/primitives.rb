Dir.glob(File.join(File.dirname(__FILE__), *%w[primitives *.rb])) do |file|
  require file.sub(/\.rb$/, '')
end

module DeferrableGratification
  # Trivial operations which return Deferrables.
  #
  # Used internally by the library, and may be useful in cases where you need
  # to return a Deferrable to keep API compatibility but the result is already
  # available.
  #
  # {DeferrableGratification} extends this module, and thus the methods here
  # are accessible via the {DG} alias.
  module Primitives
    # Return a Deferrable which immediately succeeds, passing 0 or more values
    # to callbacks.
    def success(*values)
      blank.tap {|d| d.succeed(*values) }
    end

    # Return a Deferrable which immediately succeeds, passing a constant value
    # to callbacks.
    def const(value)
      success(value)
    end

    # Return a Deferrable which immediately fails with an exception.
    #
    # @overload failure(message)
    #   Passes +RuntimeError.new(message)+ to errbacks.
    # @overload failure(exception_class)
    #   Passes +exception_class.new+ to errbacks.
    # @overload failure(exception_class, message)
    #   Passes +exception_class.new(message)+ to errbacks.
    # @overload failure(exception)
    #   Passes +exception+ to errbacks.
    def failure(exception_class_or_message, message_or_nil = nil)
      blank.tap do |d|
        d.fail(
          case exception_class_or_message
          when Exception
            raise ArgumentError, "can't specify both exception and message" if message_or_nil
            exception_class_or_message
          when Class
            exception_class_or_message.new(message_or_nil)
          else
            RuntimeError.new(exception_class_or_message.to_s)
          end)
      end
    end

    # Return a completely uninteresting Deferrable.
    def blank
      DeferrableGratification::DefaultDeferrable.new
    end
  end
end
