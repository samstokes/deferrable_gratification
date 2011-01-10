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

      describe 'after #go' do
        before { subject.go }
        it { should succeed_with(1 + 2) }
      end
    end

    describe 'DG.failure("does not compute") >> DG.lift {|x| x + 2 }' do
      subject { DG.failure("does not compute") >> DG.lift {|x| x + 2 } }

      describe 'after #go' do
        before { subject.go }
        it { should fail_with(/does not compute/) }
      end
    end

    describe 'DG.const(1) >> DG.failure("why disassemble?")' do
      subject { DG.const(1) >> DG.failure("why disassemble?") }

      describe 'after #go' do
        before { subject.go }
        it { should fail_with(/why disassemble?/) }
      end
    end
  end


  describe '#<<' do
    describe 'DG.lift {|x| x + 2 } << DG.const(1)' do
      subject { DG.lift {|x| x + 2 } << DG.const(1) }

      describe 'after #go' do
        before { subject.go }
        it { should succeed_with(2 + 1) }
      end
    end

    describe 'DG.failure("does not compute") << DG.const(1)' do
      subject { DG.failure("does not compute") << DG.const(1) }

      describe 'after #go' do
        before { subject.go }
        it { should fail_with(/does not compute/) }
      end
    end

    describe 'DG.lift {|x| x + 2 } << DG.failure("why disassemble?")' do
      subject { DG.lift {|x| x + 2 } << DG.failure("why disassemble?") }

      describe 'after #go' do
        before { subject.go }
        it { should fail_with(/why disassemble?/) }
      end
    end
  end


  describe '#map' do
    describe 'DG.const("Hello").map(&:upcase)' do
      subject { DG.const("Hello").map(&:upcase) }

      describe 'after #go' do
        before { subject.go }
        it { should succeed_with('HELLO') }
      end
    end

    describe 'DG.failure("oops").map(&:upcase)' do
      subject { DG.failure("oops").map(&:upcase) }

      describe 'after #go' do
        before { subject.go }
        it { should fail_with(/oops/) }
      end
    end

    describe 'DG.const("Hello").map { raise "kaboom!" }' do
      subject { DG.const("Hello").map { raise "kaboom!" } }

      it 'should catch the exception' do
        lambda { subject.go }.should_not raise_error
      end

      describe 'after #go' do
        before { subject.go }
        it 'should fail and pass through the exception' do
          subject.should fail_with(RuntimeError, /kaboom!/)
        end
      end
    end

    describe 'passing a bound method to save results in an external array' do
      before { @results = [] }

      subject do
        DG.const("Hello").map(&:upcase).map(&@results.method(:<<))
      end

      it 'should succeed and push the result into the array' do
        subject.go
        @results.should == ["HELLO"]
      end
    end
  end


  describe '#bind!' do
    let(:first_operation) { DG::DefaultDeferrable.new }

    describe '@results = []; first_operation.bind!(&@results.method(:<<))' do
      before do
        @results = []
        first_operation.bind!(&@results.method(:<<))
      end

      describe 'if first operation succeeds with :wahey!' do
        before { first_operation.succeed :wahey! }

        it 'should add :wahey! to @results' do
          @results.should == [:wahey!]
        end
      end

      describe 'if first operation fails' do
        before { first_operation.fail RuntimeError.new('Boom!') }

        it 'should not touch @results' do
          @results.should be_empty
        end
      end
    end

    describe 'first_operation.bind! { raise "I am buggy" }' do
      before { first_operation.bind! { raise "I am buggy" } }

      it 'should not stop the first operation from succeeding' do
        first_operation.succeed :woohoo
        first_operation.should succeed_with(:woohoo)
      end
    end

    describe 'first_operation.bind! {|name| begin_greeter(name) }' do
      describe 'returned value' do
        subject { first_operation.bind! {|name| begin_greeter(name) } }

        def begin_greeter(name)
          DG.const("Hello #{name}!").tap(&:go)
        end

        before { pending 'bind result of block to Bind2 status' }

        describe 'if first operation succeeds with "Sam"' do
          before { first_operation.succeed('Sam') }

          it { should succeed_with('Hello Sam!') }
        end
      end
    end
  end


  describe '.lift' do
    describe 'DG.lift {|result| result.class }' do
      subject { DG.lift {|result| result.class } }

      describe 'after #go(:i_am_a_symbol)' do
        before { subject.go(:i_am_a_symbol) }

        it { should succeed_with(Symbol) }
      end
    end

    describe 'DG.lift { raise "Oops" }' do
      subject { DG.lift { raise "Oops" } }

      describe 'after #go(:i_am_a_symbol)' do
        before { subject.go(:i_am_a_symbol) }

        it 'should fail and pass through the exception' do
          subject.should fail_with(RuntimeError, /Oops/)
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

      describe 'after #go' do
        before { subject.go }
        it { should succeed_with(2) }
      end
    end

    describe 'DG.chain(DG.const(1), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.lift {|x| x + 4 })' do
      subject { DG.chain(DG.const(1), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.lift {|x| x + 4 }) }

      describe 'after #go' do
        before { subject.go }
        it { should succeed_with(1 + 2 + 3 + 4) }
      end
    end

    describe 'DG.chain(DG.failure("oops"))' do
      subject { DG.chain(DG.failure("oops")) }

      describe 'after #go' do
        before { subject.go }
        it { should fail_with(/oops/) }
      end
    end

    describe 'DG.chain(DG.failure("doh"), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.lift {|x| x + 4 })' do
      subject { DG.chain(DG.failure("doh"), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.lift {|x| x + 4 }) }

      describe 'after #go' do
        before { subject.go }
        it { should fail_with(/doh/) }
      end
    end

    describe 'DG.chain(DG.const(1), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.failure("so close!"))' do
      subject { DG.chain(DG.const(1), DG.lift {|x| x + 2 }, DG.lift {|x| x + 3 }, DG.failure("so close!")) }

      describe 'after #go' do
        before { subject.go }
        it { should fail_with(/so close!/) }
      end
    end
  end
end
