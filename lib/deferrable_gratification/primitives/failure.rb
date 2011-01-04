require File.join(File.dirname(__FILE__), *%w[.. default_deferrable])

module DeferrableGratification
  module Primitives
    # Deferrable whose #go immediately fails with an exception
    class Failure < DefaultDeferrable
      def initialize(class_or_message, message_or_nil = nil)
        @error = case class_or_message
                 when Class
                   class_or_message.new(message_or_nil)
                 else
                   RuntimeError.new(class_or_message.to_s)
                 end

      end

      def go(*args); fail(@error); end
    end
  end
end
