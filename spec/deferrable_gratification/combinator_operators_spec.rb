require 'deferrable_gratification'

describe DeferrableGratification::CombinatorOperators do
  # Example deferrable which immediately succeeds with a constant value
  # e.g. DeferredConstant.new(1).go =~> 1
  class DeferredConstant < DG::DefaultDeferrable
    def initialize(value); @value = value; end
    def go; succeed(@value); end
  end
  def const_d(value); DeferredConstant.new(value); end

  # Example deferrable which immediately succeeds with the sum of the lhs
  # passed to its constructor and the rhs passed to #go.
  # e.g. DeferredPlus.new(2).go(1) =~> 3
  class DeferredPlus < DG::DefaultDeferrable
    def initialize(lhs); @lhs = lhs; end
    def go(rhs); succeed(@lhs + rhs); end
  end
  def plus_d(lhs); DeferredPlus.new(lhs); end

  # Example deferrable which immediately fails.
  class DeferredFailure < DG::DefaultDeferrable
    def initialize(error = 'oops'); @error = error; end
    def go(*args); fail(@error); end
  end
  def fail_d(*args); DeferredFailure.new(*args); end


  describe '#>>' do
    describe 'DeferredConstant.new(1) >> DeferredPlus.new(2)' do
      subject { DeferredConstant.new(1) >> DeferredPlus.new(2) }

      it 'should succeed with 1 + 2' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == (1 + 2)
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
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == (2 + 1)
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


  describe '#map' do
    describe 'DeferredConstant.new("Hello").map(&:upcase)' do
      subject { DeferredConstant.new("Hello").map(&:upcase) }

      it 'should succeed with "HELLO"' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == 'HELLO'
      end
    end

    describe 'DeferredFailure.new("oops").map(&:upcase)' do
      subject { DeferredFailure.new("oops").map(&:upcase) }

      it 'should fail with "oops"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should == 'oops'
      end
    end

    describe 'DeferredConstant.new("Hello").map { raise "kaboom!" }' do
      subject { DeferredConstant.new("Hello").map { raise "kaboom!" } }

      it 'should catch the exception' do
        lambda { subject.go }.should_not raise_error
      end

      it 'should fail and pass through the exception' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should be_a(RuntimeError)
        error.message.should =~ /kaboom!/
      end
    end
  end


  describe '.lift' do
    describe 'DG::DefaultDeferrable.lift {|result| result.class }' do
      subject { DG::DefaultDeferrable.lift {|result| result.class } }

      describe 'after #go(:i_am_a_symbol)' do
        before { subject.go(:i_am_a_symbol) }

        it 'should succeed with Symbol' do
          result = nil
          subject.callback {|r| result = r }
          result.should == Symbol
        end
      end
    end

    describe 'DG::DefaultDeferrable.lift { raise "Oops" }' do
      subject { DG::DefaultDeferrable.lift { raise "Oops" } }

      describe 'after #go(:i_am_a_symbol)' do
        before { subject.go(:i_am_a_symbol) }

        it 'should fail and pass through the exception' do
          error = nil
          subject.errback {|e| error = e }
          error.should be_a(RuntimeError)
          error.message.should =~ /Oops/
        end
      end
    end
  end


  describe '.chain' do
    describe 'DG::DefaultDeferrable.chain()' do
      subject { DG::DefaultDeferrable.chain() }
      it { should be_nil }
    end

    describe 'DG::DefaultDeferrable.chain(const_d(2))' do
      subject { DG::DefaultDeferrable.chain(const_d(2)) }

      it 'should succeed with 2' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == 2
      end
    end

    describe 'DG::DefaultDeferrable.chain(const_d(1), plus_d(2), plus_d(3), plus_d(4))' do
      subject { DG::DefaultDeferrable.chain(const_d(1), plus_d(2), plus_d(3), plus_d(4)) }

      it 'should succeed with 1 + 2 + 3 + 4' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == (1 + 2 + 3 + 4)
      end
    end

    describe 'DG::DefaultDeferrable.chain(fail_d("oops"))' do
      subject { DG::DefaultDeferrable.chain(fail_d("oops")) }

      it 'should fail with "oops"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should == "oops"
      end
    end

    describe 'DG::DefaultDeferrable.chain(fail_d("doh"), plus_d(2), plus_d(3), plus_d(4))' do
      subject { DG::DefaultDeferrable.chain(fail_d("doh"), plus_d(2), plus_d(3), plus_d(4)) }

      it 'should fail with "doh"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should == "doh"
      end
    end

    describe 'DG::DefaultDeferrable.chain(const_d(1), plus_d(2), plus_d(3), fail_d("so close!"))' do
      subject { DG::DefaultDeferrable.chain(const_d(1), plus_d(2), plus_d(3), fail_d("so close!")) }

      it 'should fail with "so close!"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should == "so close!"
      end
    end
  end
end
