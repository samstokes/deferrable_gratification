require 'deferrable_gratification'

describe DeferrableGratification::Combinators::Bind do
  let(:first_deferrable) { EventMachine::DefaultDeferrable.new }

  describe 'constructed with a block returning a deferrable' do
    describe 'side effects on first deferrable' do
      subject { first_deferrable }
      before { bind.setup! }

      describe 'if block behaves itself' do
        let(:bind) do
          described_class.new(first_deferrable) {|value| DummyDB.query(:value => value) }
        end

        describe 'if first Deferrable succeeds' do
          it 'should invoke the block with the value passed to #succeed' do
            DummyDB.should_receive(:query).with(:value => :wahey).and_return EM::DefaultDeferrable.new
            subject.succeed(:wahey)
          end
        end

        describe 'if first Deferrable fails' do
          it 'should not invoke the block' do
            DummyDB.should_not_receive(:query)
            subject.fail(RuntimeError.new('sadface :('))
          end
        end
      end

      describe 'if block calls first_deferrable.fail' do
        # EM::Deferrable callbacks are allowed to re-set the Deferrable's
        # status, triggering errbacks as if it had failed in the first place.
        # Our bound blocks should have the same behaviour.

        let(:bind) do
          described_class.new(first_deferrable) do
            # maybe the block does some validation on the result, and then
            # retries with a more expensive query if the validation fails.
            first_deferrable.fail(RuntimeError.new('found invalid user'))
            DummyDB.query(:expensive_id, :name => 'Bob')
          end
        end

        before { subject.succeed }

        it { should fail_with(RuntimeError, 'found invalid user') }
      end
    end

    describe "the #{described_class} Deferrable itself" do
      subject { bind }
      before { subject.setup! }

      it_should_behave_like 'a Deferrable'

      let(:bind) { described_class.new(first_deferrable) {|value| DummyDB.query(:value => value) } }

      describe 'if first Deferrable succeeds' do
        describe 'if the Deferrable returned by the block succeeds' do
          before { DummyDB.stub_successful_query(:value => 42) { "you're not going to like it" } }

          it 'should succeed with the value that Deferrable succeeded with' do
            first_deferrable.succeed(42)
            subject.should succeed_with "you're not going to like it"
          end
        end

        describe 'if the Deferrable returned by the block fails' do
          before { DummyDB.stub_failing_query(:value => 42) { "we're going to get lynched" } }

          it 'should fail with the error that Deferrable failed with' do
            first_deferrable.succeed(42)
            subject.should fail_with "we're going to get lynched"
          end
        end

        describe 'if block calls first_deferrable.fail' do
          # EM::Deferrable callbacks are allowed to re-set the Deferrable's
          # status, triggering errbacks as if it had failed in the first place.
          # Our bound blocks should have the same behaviour.

          let(:bind) do
            described_class.new(first_deferrable) do
              # maybe the block does some validation on the result, and then
              # retries with a more expensive query if the validation fails.
              first_deferrable.fail(RuntimeError.new('found invalid user'))
              DummyDB.query(:expensive_id, :name => 'Bob')
            end
          end

          before { first_deferrable.succeed }

          it { should fail_with(RuntimeError, 'found invalid user') }
        end
      end

      describe 'if first Deferrable fails with RuntimeError' do
        before { first_deferrable.fail(RuntimeError.new('oops')) }

        it { should fail_with RuntimeError }
      end
    end
  end


  describe 'constructed with a block not returning a Deferrable' do
    describe 'side effects' do
      subject { first_deferrable }
      before { bind.setup! }

      let(:results) { [] }
      let(:bind) do
        described_class.new(first_deferrable) {|value| results << value }
      end

      describe 'if first Deferrable succeeds' do
        it 'should invoke the block anyway' do
          subject.succeed(:wahey)
          results.should == [:wahey]
        end

        describe 'if block raises an exception' do
          let(:bind) { described_class.new(first_deferrable) { raise 'Boom!' } }

          it 'should not prevent the first Deferrable succeeding' do
            subject.succeed(:woohoo)
            subject.should succeed_with(:woohoo)
          end
        end

      end
    end

    describe "the #{described_class} Deferrable itself" do
      subject { bind }
      before { subject.setup! }

      let(:bind) do
        described_class.new(first_deferrable) {|value| value.upcase }
      end

      it_should_behave_like 'a Deferrable'

      describe 'if first Deferrable succeeds' do
        before { first_deferrable.succeed('hello') }

        it 'should succeed with whatever the block returned' do
          subject.should succeed_with 'HELLO'
        end

        describe 'if block raises an exception' do
          let(:bind) do
            described_class.new(first_deferrable) { raise 'Kaboom' }
          end

          it 'should fail and pass through the exception' do
            subject.should fail_with 'Kaboom'
          end
        end
      end
    end
  end


  describe 'nested bind! equivalent to chained bind! (monad law: associativity)' do
    # This sounds complicated, but basically means you can swap between a
    # nested sequence of bind! calls and a chained sequence of bind! calls
    # with the same blocks in the same order.  The latter may be more readable
    # and also improves encapsulation (since the nested version leaks variables
    # into inner scopes by creating closures).

    class << self
      def good_op(x); DG.const(x); end
      def bad_op(*_); DG.failure(RuntimeError, 'Oops'); end
      def transform(x); x.succ; end
      def boom(*_); raise 'Boom!'; end
    end

    # Apologies for the nasty metaprogramming but I can't find a better way of
    # testing all the cases.
    #
    # For the cases => false, the two syntaxes should *not* behave the same:
    # the nested syntax doesn't really make sense for these cases, because
    # bind! no longer behaves as a monad and thus the values being passed to
    # the blocks don't support the bind! operator.
    {
      %w(good_op good_op good_op)     => true,

      %w(good_op good_op   transform) => true,

      %w(good_op transform   good_op) => false,
      %w(good_op transform transform) => false,

      %w(good_op good_op  bad_op)     => true,
      %w(good_op  bad_op good_op)     => true,
      %w( bad_op good_op good_op)     => true,

      %w(good_op good_op boom)        => true,
      %w(good_op boom good_op)        => true,
    }.map do |methods, should_be_equivalent|
      [methods.map {|m| method m }, should_be_equivalent]
    end.each do |(first, second, third), should_be_equivalent|
      describe %-#{first.name}(0).bind! do |x|
                   #{second.name}(x)
                 end.bind! do |y|
                   #{third.name}(y)
                 end- do
        subject do
          first[0].bind! do |x|
            second[x]
          end.bind! do |y|
            third[y]
          end
        end

        it %-should #{should_be_equivalent ? '' : 'NOT '}behave the same as:
                #{first.name}(0).bind! do |x|
                  #{second.name}(x).bind! do |y|
                    #{third.name}(y)
                  end
                end- do
          success = SpecTools::ResultReceiver.new
          failure = SpecTools::ResultReceiver.new

          nested = first[0].bind! do |x|
                     second[x].bind! do |y|
                       third[y]
                     end
                   end

          nested.callback {|result| success.result = result }
          nested.errback {|error| failure.result = error }

          behave_the_same = if success.has_result?
            succeed_with(success.result)
          else
            fail_with(failure.result.class, failure.result.message)
          end

          if should_be_equivalent
            subject.should behave_the_same
          else
            subject.should_not behave_the_same
          end
        end
      end
    end
  end


  describe '.setup! without a block' do
    specify '.new should raise ArgumentError' do
      lambda { described_class.new(first_deferrable) }.
        should raise_error(ArgumentError)
    end
  end
end
