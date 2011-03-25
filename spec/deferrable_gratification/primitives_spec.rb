require 'deferrable_gratification'

describe DeferrableGratification::Primitives do
  describe '.success' do
    describe 'DG.success' do
      subject { DG.success }

      it { should succeed_with_anything }
    end

    describe 'DG.success(42)' do
      subject { DG.success(42) }

      it { should succeed_with 42 }
    end

    describe 'DG.success(:foo, :bar, :baz)' do
      subject { DG.success(:foo, :bar, :baz) }

      it { should succeed_with [:foo, :bar, :baz] }
    end
  end


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

    describe 'DG.failure(RangeError.new("you shall not pass!"))' do
      subject { DG.failure(RangeError.new("you shall not pass!")) }

      it { should fail_with(RangeError, 'you shall not pass!') }
    end
  end
end
