require 'deferrable_gratification'

describe DeferrableGratification::Combinators::Map do
  before { @deferrable = MockDeferrable.new }

  subject { described_class.new(@deferrable) {|result| result.class } }

  it_should_behave_like 'a Deferrable'

  it 'should execute the Deferrable' do
    @deferrable.should_receive(:go)
    subject.go
  end

  it 'should pass arguments to #go through to the Deferrable' do
    @deferrable.should_receive(:go).with('foo', 'bar', 'baz')
    subject.go('foo', 'bar', 'baz')
  end


  describe '(if the Deferrable succeeds)' do
    before { @deferrable.stub_success!(:result) }

    it 'should succeed with the result of passing the Deferrable result through the function' do
      result = nil
      subject.callback {|r| result = r }
      subject.go
      result.should == Symbol
    end

    describe '(if the block throws an exception)' do
      subject { described_class.new(@deferrable) { raise "kaboom!" } }

      it 'should not throw the exception synchronously' do
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


  describe '(if the Deferrable fails)' do
    before { @deferrable.stub_failure!('oops') }

    it 'should call its errbacks' do
      called = false
      subject.errback { called = true }
      subject.go

      called.should be_true
    end
  end


  describe '(if not passed a block)' do
    it 'should raise ArgumentError on construction' do
      lambda { described_class.new(@deferrable) }.should raise_error(ArgumentError)
    end
  end
end
