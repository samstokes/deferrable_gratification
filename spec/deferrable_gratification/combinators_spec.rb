require 'deferrable_gratification'

# N.B. most of these specs rely on the fact that all the example functions and
# callbacks used are synchronous, because testing the results of asynchronous
# code in RSpec is hard.  (Testing that a callback is called with the right
# value is easy; testing that it is called at all is harder.)
#
# However, the combinators should work just fine for asynchronous operations,
# or for a mixture of synchronous and asynchronous.

describe DeferrableGratification::Combinators do
  describe '#>>' do
    describe 'DG.const(1) >> DG.lift {|x| x + 2 }' do
      subject { DG.const(1) >> DG.lift {|x| x + 2 } }

      it 'should succeed with 1 + 2' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == (1 + 2)
      end
    end

    describe 'DG.failure("does not compute") >> DG.lift {|x| x + 2 }' do
      subject { DG.failure("does not compute") >> DG.lift {|x| x + 2 } }

      it 'should fail with "does not compute"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /does not compute/
      end
    end

    describe 'DG.const(1) >> DG.failure("why disassemble?")' do
      subject { DG.const(1) >> DG.failure("why disassemble?") }

      it 'should fail with "why disassemble?"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /why disassemble\?/
      end
    end
  end


  describe '#<<' do
    describe 'DG.lift {|x| x + 2 } << DG.const(1)' do
      subject { DG.lift {|x| x + 2 } << DG.const(1) }

      it 'should succeed with 2 + 1' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == (2 + 1)
      end
    end

    describe 'DG.failure("does not compute") << DG.const(1)' do
      subject { DG.failure("does not compute") << DG.const(1) }

      it 'should fail with "does not compute"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /does not compute/
      end
    end

    describe 'DG.lift {|x| x + 2 } << DG.failure("why disassemble?")' do
      subject { DG.lift {|x| x + 2 } << DG.failure("why disassemble?") }

      it 'should fail with "why disassemble?"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /why disassemble\?/
      end
    end
  end


  describe '#map' do
    describe 'DG.const("Hello").map {|x| x.upcase }' do
      subject { DG.const("Hello").map {|x| x.upcase } }

      it 'should succeed with "HELLO"' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == 'HELLO'
      end
    end

    describe 'DG.failure("oops").map {|x| x.upcase }' do
      subject { DG.failure("oops").map {|x| x.upcase } }

      it 'should fail with "oops"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /oops/
      end
    end

    describe 'DG.const("Hello").map { raise "kaboom!" }' do
      subject { DG.const("Hello").map { raise "kaboom!" } }

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
        DG.const("Hello").map {|x| x.upcase }.map(&@results.method(:<<))
      end

      it 'should succeed and push the result into the array' do
        subject.go
        @results.should == ["HELLO"]
      end
    end
  end


  describe '.lift' do
    describe 'DG.lift {|result| result.class }' do
      subject { DG.lift {|result| result.class } }

      describe 'after #go(:i_am_a_symbol)' do
        before { subject.go(:i_am_a_symbol) }

        it 'should succeed with Symbol' do
          result = nil
          subject.callback {|r| result = r }
          result.should == Symbol
        end
      end
    end

    describe 'DG.lift { raise "Oops" }' do
      subject { DG.lift { raise "Oops" } }

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
    describe 'DG.chain()' do
      subject { DG.chain() }
      it { should be_nil }
    end

    describe 'DG.chain(DG.const(2))' do
      subject { DG.chain(DG.const(2)) }

      it 'should succeed with 2' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == 2
      end
    end

    describe 'DG.chain(DG.const(1), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.lift {|x| x + 4 })' do
      subject { DG.chain(DG.const(1), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.lift {|x| x + 4 }) }

      it 'should succeed with 1 + 2 + 3 + 4' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == (1 + 2 + 3 + 4)
      end
    end

    describe 'DG.chain(DG.failure("oops"))' do
      subject { DG.chain(DG.failure("oops")) }

      it 'should fail with "oops"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /oops/
      end
    end

    describe 'DG.chain(DG.failure("doh"), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.lift {|x| x + 4 })' do
      subject { DG.chain(DG.failure("doh"), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.lift {|x| x + 4 }) }

      it 'should fail with "doh"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /doh/
      end
    end

    describe 'DG.chain(DG.const(1), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.failure("so close!"))' do
      subject { DG.chain(DG.const(1), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.failure("so close!")) }

      it 'should fail with "so close!"' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.to_s.should =~ /so close!/
      end
    end
  end
end
