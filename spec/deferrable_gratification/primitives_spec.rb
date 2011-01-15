require 'deferrable_gratification'

describe DeferrableGratification::Primitives do
  describe '.const' do
    describe 'DG.const("Hello")' do
      subject { DG.const("Hello") }

      it { should succeed_with('Hello') }
    end
  end


  describe '.failure' do
    describe 'DG.failure("does not compute")' do
      subject { DG.failure("does not compute") }
      
      it { should fail_with(RuntimeError, 'does not compute') }
    end

    describe 'DG.failure(ArgumentError)' do
      subject { DG.failure(ArgumentError) }

      it { should fail_with(ArgumentError) }
    end

    describe 'DG.failure(ArgumentError, "unacceptable command")' do
      subject { DG.failure(ArgumentError, "unacceptable command") }

      it { should fail_with(ArgumentError, 'unacceptable command') }
    end
  end
end
