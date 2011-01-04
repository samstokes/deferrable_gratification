require 'deferrable_gratification'

# N.B. most of these specs rely on the fact that all the example functions and
# callbacks used are synchronous, because testing the results of asynchronous
# code in RSpec is hard.  (Testing that a callback is called with the right
# value is easy; testing that it is called at all is harder.)
#
# However, the combinators should work just fine for asynchronous operations,
# or for a mixture of synchronous and asynchronous.

describe DeferrableGratification::Combinators do
  module Primitives
    extend DeferrableGratification::Primitives
  end


  def plus_d(n)
    DG::DefaultDeferrable.lift {|x| x + n }
  end


  describe '#>>' do
    describe 'Primitives.const(1) >> plus_d(2)' do
      subject { Primitives.const(1) >> plus_d(2) }

      it 'should succeed with 1 + 2' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == (1 + 2)
      end
    end

    describe 'Primitives.failure("does not compute") >> plus_d(2)' do
      subject { Primitives.failure("does not compute") >> plus_d(2) }

      it 'should fail with "does not compute"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /does not compute/
      end
    end

    describe 'Primitives.const(1) >> Primitives.failure("why disassemble?")' do
      subject { Primitives.const(1) >> Primitives.failure("why disassemble?") }

      it 'should fail with "why disassemble?"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /why disassemble\?/
      end
    end
  end


  describe '#<<' do
    describe 'plus_d(2) << Primitives.const(1)' do
      subject { plus_d(2) << Primitives.const(1) }

      it 'should succeed with 2 + 1' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == (2 + 1)
      end
    end

    describe 'Primitives.failure("does not compute") << Primitives.const(1)' do
      subject { Primitives.failure("does not compute") << Primitives.const(1) }

      it 'should fail with "does not compute"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /does not compute/
      end
    end

    describe 'plus_d(2) << Primitives.failure("why disassemble?")' do
      subject { plus_d(2) << Primitives.failure("why disassemble?") }

      it 'should fail with "why disassemble?"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /why disassemble\?/
      end
    end
  end


  describe '#map' do
    describe 'Primitives.const("Hello").map(&:upcase)' do
      subject { Primitives.const("Hello").map(&:upcase) }

      it 'should succeed with "HELLO"' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == 'HELLO'
      end
    end

    describe 'Primitives.failure("oops").map(&:upcase)' do
      subject { Primitives.failure("oops").map(&:upcase) }

      it 'should fail with "oops"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /oops/
      end
    end

    describe 'Primitives.const("Hello").map { raise "kaboom!" }' do
      subject { Primitives.const("Hello").map { raise "kaboom!" } }

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

    describe 'passing a bound method to save results in an external array' do
      before { @results = [] }

      subject do
        Primitives.const("Hello").map(&:upcase).map(&@results.method(:<<))
      end

      it 'should succeed and push the result into the array' do
        subject.go
        @results.should == ["HELLO"]
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

    describe 'DG::DefaultDeferrable.chain(Primitives.const(2))' do
      subject { DG::DefaultDeferrable.chain(Primitives.const(2)) }

      it 'should succeed with 2' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == 2
      end
    end

    describe 'DG::DefaultDeferrable.chain(Primitives.const(1), plus_d(2), plus_d(3), plus_d(4))' do
      subject { DG::DefaultDeferrable.chain(Primitives.const(1), plus_d(2), plus_d(3), plus_d(4)) }

      it 'should succeed with 1 + 2 + 3 + 4' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == (1 + 2 + 3 + 4)
      end
    end

    describe 'DG::DefaultDeferrable.chain(Primitives.failure("oops"))' do
      subject { DG::DefaultDeferrable.chain(Primitives.failure("oops")) }

      it 'should fail with "oops"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /oops/
      end
    end

    describe 'DG::DefaultDeferrable.chain(Primitives.failure("doh"), plus_d(2), plus_d(3), plus_d(4))' do
      subject { DG::DefaultDeferrable.chain(Primitives.failure("doh"), plus_d(2), plus_d(3), plus_d(4)) }

      it 'should fail with "doh"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /doh/
      end
    end

    describe 'DG::DefaultDeferrable.chain(Primitives.const(1), plus_d(2), plus_d(3), Primitives.failure("so close!"))' do
      subject { DG::DefaultDeferrable.chain(Primitives.const(1), plus_d(2), plus_d(3), Primitives.failure("so close!")) }

      it 'should fail with "so close!"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /so close!/
      end
    end
  end
end
