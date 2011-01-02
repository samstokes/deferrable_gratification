require 'em/deferrable/combinator_operators'

describe EventMachine::Deferrable do
  class DeferrableWithOperators
    include EventMachine::Deferrable
    include EventMachine::Deferrable::CombinatorOperators
  end

  # Example deferrable which immediately succeeds with a constant value
  # e.g. DeferredConstant.new(1).go =~> 1
  class DeferredConstant < DeferrableWithOperators
    def initialize(value); @value = value; end
    def go; succeed(@value); end
  end

  # Example deferrable which immediately succeeds with the sum of the lhs
  # passed to its constructor and the rhs passed to #go.
  # e.g. DeferredPlus.new(2).go(1) =~> 3
  class DeferredPlus < DeferrableWithOperators
    def initialize(lhs); @lhs = lhs; end
    def go(rhs); succeed(@lhs + rhs); end
  end

  # Example deferrable which immediately fails.
  class DeferredFailure < DeferrableWithOperators
    def initialize(error = 'oops'); @error = error; end
    def go(*args); fail(@error); end
  end


  describe '#>>' do
    describe 'DeferredConstant.new(1) >> DeferredPlus.new(2)' do
      subject { DeferredConstant.new(1) >> DeferredPlus.new(2) }

      it 'should succeed with 1 + 2' do
        subject.callback {|result| result.should == (1 + 2) }
        subject.go
      end
    end

    describe 'DeferredFailure.new("does not compute") >> DeferredPlus.new(2)' do
      subject { DeferredFailure.new("does not compute") >> DeferredPlus.new(2) }

      it 'should fail with "does not compute"' do
        subject.errback {|error| error.should == 'does not compute' }
        subject.go
      end
    end

    describe 'DeferredConstant.new(1) >> DeferredFailure.new("why disassemble?")' do
      subject { DeferredConstant.new(1) >> DeferredFailure.new("why disassemble?") }

      it 'should fail with "why disassemble?"' do
        subject.errback {|error| error.should == 'why disassemble?' }
        subject.go
      end
    end
  end
end
