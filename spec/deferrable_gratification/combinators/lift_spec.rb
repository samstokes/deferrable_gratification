require 'deferrable_gratification'

describe DeferrableGratification::Combinators::Lift do
  describe 'constructed with a block' do
    subject { described_class.new {|radius| Math::PI * radius * radius } }

    it_should_behave_like 'a Deferrable'
    it_should_behave_like 'a launchable task'

    describe 'after #go(arg)' do
      it 'should succeed with the result of passing arg through the block' do
        result = nil
        subject.callback {|r| result = r }
        subject.go(2)
        result.should == (Math::PI * 2 * 2)
      end
    end

    describe 'if the block throws an exception' do
      subject { described_class.new { raise 'kaboom!' } }

      it 'should not throw the exception synchronously on #go' do
        lambda { subject.go }.should_not raise_error
      end

      it 'should fail and pass through the exception' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should be_a(RuntimeError)
        error.message.should =~ /kaboom!/
      end

      it 'should not catch exceptions thrown by #succeed itself (e.g. buggy callbacks)' do
        subject = described_class.new {|x| x + 1 }
        subject.callback { raise 'Oops buggy callback' }

        subject.errback {|e| fail "errback shouldn't have fired, but did with #{e}" }

        lambda { subject.go(1) }.should raise_error('Oops buggy callback')
      end
    end
  end


  describe 'constructed with no block' do
    it 'should raise ArgumentError' do
      lambda { described_class.new }.should raise_error(ArgumentError)
    end
  end
end
