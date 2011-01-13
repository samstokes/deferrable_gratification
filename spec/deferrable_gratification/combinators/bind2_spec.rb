require 'deferrable_gratification'

describe DeferrableGratification::Combinators::Bind2 do
  let(:first_deferrable) { EventMachine::DefaultDeferrable.new }

  DummyDB = SpecTools::DummyDB

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

      describe 'if block raises an exception' do
        let(:bind) { described_class.new(first_deferrable) { raise 'Boom!' } }

        it 'should not prevent the first Deferrable succeeding' do
          subject.succeed(:woohoo)
          subject.should succeed_with(:woohoo)
        end
      end

      describe 'if block calls first_deferrable.fail' do
        # EM::Deferrable callbacks are allowed to re-set the Deferrable's
        # status, triggering errbacks as if it had failed in the first place.
        # Our bound blocks should have the same behaviour.

        let(:bind) do
          described_class.new(first_deferrable) do
            first_deferrable.fail(RuntimeError.new('nice try'))
          end
        end

        before { subject.succeed }

        it { should fail_with(RuntimeError, 'nice try') }
      end
    end

    describe "the #{described_class} Deferrable itself" do
      subject { bind }
      before { subject.setup! }

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
              first_deferrable.fail(RuntimeError.new('nice try'))
            end
          end

          before { first_deferrable.succeed }

          it { should fail_with(RuntimeError, 'nice try') }
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
      end
    end

    describe "the #{described_class} Deferrable itself" do
      before { pending 'not yet implemented' }
      subject { bind }
      before { subject.setup! }

      describe 'if first Deferrable succeeds' do
        before { first_deferrable.succeed('hello') }

        describe 'if block returns a value' do
          let(:bind) do
            described_class.new(first_deferrable) {|value| value.upcase }
          end

          it 'should succeed with whatever the block returned' do
            subject.should succeed_with 'HELLO'
          end
        end

        describe 'if block raises an exception' do
          let(:bind) do
            described_class.new(first_deferrable) { raise 'Kaboom' }
          end

          it 'should still succeed with whatever the first deferrable succeeded with' do
            subject.should succeed_with 'hello'
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
