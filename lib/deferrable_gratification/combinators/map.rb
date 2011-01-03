require File.join(File.dirname(__FILE__), *%w[.. default_deferrable])

module DeferrableGratification
  module Combinators
    class Map < DefaultDeferrable
      def initialize(deferrable, &block)
        @deferrable = deferrable

        raise ArgumentError, 'must be called with a block' unless block
        @function = block  # now a proc
      end

      def go(*args)
        @deferrable.callback do |*args|
          begin
            result = @function.call(*args)
          rescue => error
          end

          if error
            fail(error)
          else
            succeed(result)
          end
        end

        @deferrable.errback {|error| fail(error) }

        @deferrable.go(*args)
      end
    end
  end
end
