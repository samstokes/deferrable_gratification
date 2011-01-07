require 'deferrable_gratification'

describe DeferrableGratification::Combinators::Bind do
  before do
    @first = MockDeferrable.new
    @second = MockDeferrable.new
  end


  subject { described_class.new(@first, @second) }


  it_should_behave_like 'a Deferrable'
  it_should_behave_like 'a launchable task'

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

      describe 'after #go' do
        before { subject.go }

        it 'should call its callbacks with the successful result of the second Deferrable' do
          subject.should succeed_with(:second_result)
        end
      end
    end

    describe '(if second Deferrable fails)' do
      before { @second.stub_failure!(RuntimeError.new('sorry')) }

      describe 'after #go' do
        before { subject.go }

        it 'should call its errbacks' do
          subject.should fail_with(/.*/)
        end
      end
    end
  end


  describe '(if the first Deferrable fails)' do
    before { @first.stub_failure!(RuntimeError.new('oops')) }

    it 'should not execute the second Deferrable at all' do
      @second.should_not_receive(:go)
      subject.go
    end

    describe 'after #go' do
      before { subject.go }

      it 'should call its errbacks' do
        subject.should fail_with(/.*/)
      end
    end
  end
end
