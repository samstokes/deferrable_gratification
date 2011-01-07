require 'deferrable_gratification'

describe DeferrableGratification::Primitives do
  describe '.const' do
    describe 'DG.const("Hello")' do
      subject { DG.const("Hello") }

      describe 'after #go' do
        before { subject.go }
        it { should succeed_with('Hello') }
      end
    end
  end


  describe '.failure' do
    describe 'DG.failure("does not compute")' do
      subject { DG.failure("does not compute") }
      
      describe 'after #go' do
        before { subject.go }
        it { should fail_with(RuntimeError, 'does not compute') }
      end
    end

    describe 'DG.failure(ArgumentError)' do
      subject { DG.failure(ArgumentError) }

      describe 'after #go' do
        before { subject.go }
        it { should fail_with(ArgumentError) }
      end
    end

    describe 'DG.failure(ArgumentError, "unacceptable command")' do
      subject { DG.failure(ArgumentError, "unacceptable command") }

      describe 'after #go' do
        before { subject.go }
        it { should fail_with(ArgumentError, 'unacceptable command') }
      end
    end
  end
end
