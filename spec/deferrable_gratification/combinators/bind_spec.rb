require 'deferrable_gratification'

describe DeferrableGratification::Combinators::Bind do
  before do
    @first = MockDeferrable.new
    @second = MockDeferrable.new
  end


  subject { described_class.new(@first, @second) }


  it_should_behave_like 'a Deferrable'

  it 'should execute the first Deferrable' do
    @first.should_receive(:go)
    subject.go
  end

  it 'should pass arguments to #go through to the first Deferrable' do
    @first.should_receive(:go).with('foo', 'bar', 'baz')
    subject.go('foo', 'bar', 'baz')
  end


  describe '(if the first Deferrable succeeds)' do
    before { @first.stub_success!(:first_result) }

    it 'should execute the second Deferrable' do
      @second.should_receive(:go)
      subject.go
    end

    it 'should pass the successful result of the first Deferrable to the second Deferrable' do
      @second.should_receive(:go).with(:first_result)
      subject.go
    end

    describe '(if the second Deferrable succeeds)' do
      before { @second.stub_success!(:second_result) }

      it 'should call its callbacks with the successful result of the second Deferrable' do
        subject.callback {|result| result.should == :second_result }
        subject.go
      end
    end

    describe '(if second Deferrable fails)' do
      before { @second.stub_failure!('sorry') }

      it 'should call its errbacks' do
        called = false
        subject.errback { called = true }
        subject.go

        called.should be_true
      end
    end
  end


  describe '(if the first Deferrable fails)' do
    before { @first.stub_failure!('oops') }

    it 'should not execute the second Deferrable at all' do
      @second.should_not_receive(:go)
      subject.go
    end

    it 'should call its errbacks' do
      called = false
      subject.errback { called = true }
      subject.go

      called.should be_true
    end
  end
end
