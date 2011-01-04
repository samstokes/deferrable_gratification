require 'deferrable_gratification'

describe DeferrableGratification::Primitives do
  module Primitives
    extend DeferrableGratification::Primitives
  end


  describe '.const' do
    describe 'Primitives.const("Hello")' do
      subject { Primitives.const("Hello") }

      it 'should succeed with "Hello"' do
        result = nil
        subject.callback {|r| result = r }
        subject.go
        result.should == "Hello"
      end
    end
  end


  describe '.failure' do
    describe 'Primitives.failure("does not compute")' do
      subject { Primitives.failure("does not compute") }
      
      it 'should fail with RuntimeError("does not compute")' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should be_a(RuntimeError)
        error.message.should == "does not compute"
      end
    end

    describe 'Primitives.failure(ArgumentError)' do
      subject { Primitives.failure(ArgumentError) }

      it 'should fail with ArgumentError' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should be_an(ArgumentError)
      end
    end

    describe 'Primitives.failure(ArgumentError, "unacceptable command")' do
      subject { Primitives.failure(ArgumentError, "unacceptable command") }

      it 'should fail with ArgumentError("unacceptable command")' do
        error = nil
        subject.errback {|e| error = e }
        subject.go
        error.should be_an(ArgumentError)
        error.message.should =~ /unacceptable command/
      end
    end
  end
end
