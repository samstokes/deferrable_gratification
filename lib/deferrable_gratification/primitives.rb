Dir.glob(File.join(File.dirname(__FILE__), *%w[primitives *.rb])) do |file|
  require file.sub(/\.rb$/, '')
end

module DeferrableGratification
  module Primitives
    # Return a Deferrable which immediately succeeds with a constant value.
    def const(value)
      blank.tap {|d| d.succeed(value) }
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
