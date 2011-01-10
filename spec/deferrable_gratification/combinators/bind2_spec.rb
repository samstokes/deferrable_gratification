require 'deferrable_gratification'

describe DeferrableGratification::Combinators::Bind2 do
  let(:first_deferrable) { EventMachine::DefaultDeferrable.new }

  describe 'constructed with a block' do
    describe 'for side effect' do
      subject { first_deferrable }
      before { bind.setup! }

      describe 'if block behaves itself' do
        let(:results) { [] }
        let(:bind) do
          described_class.new(first_deferrable) {|value| results << value }
        end

        describe 'if first Deferrable succeeds' do
          before { first_deferrable.succeed(:wahey) }

          it 'should invoke the block with the value passed to #succeed' do
            results.should == [:wahey]
          end
        end

        describe 'if first Deferrable fails' do
          before { first_deferrable.fail(RuntimeError.new('sadface :(')) }

          it 'should not invoke the block' do
            results.should be_empty
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

        before { first_deferrable.succeed }

        it { should fail_with(RuntimeError, 'nice try') }
      end
    end
  end

  describe 'without a block' do
    specify '.new should raise ArgumentError' do
      lambda { described_class.new(first_deferrable) }.
        should raise_error(ArgumentError)
    end
  end
end
