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
    def failure(class_or_message, message_or_nil = nil)
      blank.tap do |d|
        d.fail(
          case class_or_message
          when Class
            class_or_message.new(message_or_nil)
          else
            RuntimeError.new(class_or_message.to_s)
          end)
      end
    end

    # Return a completely uninteresting Deferrable.
    def blank
      DeferrableGratification::DefaultDeferrable.new
    end
  end
end
