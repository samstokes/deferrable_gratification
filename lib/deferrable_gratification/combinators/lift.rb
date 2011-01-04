require File.join(File.dirname(__FILE__), *%w[.. default_deferrable])

module DeferrableGratification
  module Combinators
    class Lift < DefaultDeferrable
      def initialize(&block)
        raise ArgumentError, 'must be called with a block' unless block
        @function = block # now a proc
      end
    
      def go(*args)
        begin
          result = @function.call(*args)
        rescue => error
        end

        # this contorted-looking code is to avoid swallowing exceptions that
        # are raised by #succeed itself (e.g. if someone passes a buggy
        # callback that raises an exception).
        if error
          fail(error)
        else
          succeed(result)
        end
      end
    end
  end
end
