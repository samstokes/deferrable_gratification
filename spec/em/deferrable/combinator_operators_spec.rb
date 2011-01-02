require 'deferrable_combinators'

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
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should == 'does not compute'
      end
    end

    describe 'DeferredConstant.new(1) >> DeferredFailure.new("why disassemble?")' do
      subject { DeferredConstant.new(1) >> DeferredFailure.new("why disassemble?") }

      it 'should fail with "why disassemble?"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should == 'why disassemble?'
      end
    end
  end


  describe '#<<' do
    describe 'DeferredPlus.new(2) << DeferredConstant.new(1)' do
      subject { DeferredPlus.new(2) << DeferredConstant.new(1) }

      it 'should succeed with 2 + 1' do
        subject.callback {|result| result.should == (2 + 1) }
        subject.go
      end
    end

    describe 'DeferredFailure.new("does not compute") << DeferredConstant.new(1)' do
      subject { DeferredFailure.new("does not compute") << DeferredConstant.new(1) }

      it 'should fail with "does not compute"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should == 'does not compute'
      end
    end

    describe 'DeferredPlus.new(2) << DeferredFailure.new("why disassemble?")' do
      subject { DeferredPlus.new(2) << DeferredFailure.new("why disassemble?") }

      it 'should fail with "why disassemble?"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should == 'why disassemble?'
      end
    end
  end
end
