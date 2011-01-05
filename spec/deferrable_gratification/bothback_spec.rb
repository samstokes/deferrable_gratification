require 'deferrable_gratification'

require 'eventmachine'
require 'em/deferrable'

describe DeferrableGratification::Bothback do
  class BothbackDeferrable < EventMachine::DefaultDeferrable
    include DeferrableGratification::Bothback
  end

  subject { BothbackDeferrable.new }

  it 'should allow registering a "bothback"' do
    lambda do
      subject.bothback { release_lock }
    end.should_not raise_error
  end

  describe 'after registering a bothback' do
    before do
      @called = false
      subject.bothback { @called = true }
    end

    describe 'on success' do
      before { subject.succeed :yay }

      it 'should call the bothback' do
        @called.should be_true
      end
    end

    describe 'on failure' do
      before { subject.fail :boo }

      it 'should call the bothback' do
        @called.should be_true
      end
    end
  end
end
