require 'em/deferrable/combinators/bind'

describe EventMachine::Deferrable::Combinators::Bind do
  class MockDeferrable < EventMachine::DefaultDeferrable
    def stub_success!(*args)
      self.stub!(:go) { self.succeed(*args) }
    end

    def stub_failure!(*args)
      self.stub!(:go) { self.fail(*args) }
    end
  end

  before do
    @first = MockDeferrable.new
    @second = MockDeferrable.new
  end


  subject { described_class.new(@first, @second) }


  it 'should quack like a Deferrable' do
    should respond_to(:callback)
    should respond_to(:errback)
  end

  it 'should have a #go method to launch it' do
    should respond_to(:go)
  end

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


  describe '(if first Deferrable fails)' do
    before { @first.stub!(:go) { @first.fail('oops') } }

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
