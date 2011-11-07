require 'deferrable_gratification'

require 'eventmachine'
require 'em/deferrable'

describe DeferrableGratification::Fluent do
  class FluentDeferrable < EventMachine::DefaultDeferrable
    include DeferrableGratification::Fluent
  end

  subject { FluentDeferrable.new }

  it 'should allow fluently adding multiple callbacks' do
    lambda do
      subject.
        callback {|result| process(result) }.
        callback { log_action }.
        callback {|result| puts result }
    end.should_not raise_error
  end

  it 'should allow fluently adding multiple errbacks' do
    lambda do
      subject.
        errback {|error| report(error) }.
        errback { count_error }
    end.should_not raise_error
  end

  it 'should allow fluently setting a timeout' do
    lambda do
      EM.run do # timeout requires EventMachine
        subject.
          callback { EM.stop }.
          timeout(1).
          errback { EM.stop }
        EM.next_tick { subject.succeed } # so the test actually completes!
      end
    end.should_not raise_error
  end

  it 'should allow fluently mixing callbacks and errbacks' do
    lambda do
      subject.
        callback {|result| process(result) }.
        errback { count_error }.
        callback { log_action }
    end.should_not raise_error
  end

  describe 'after fluently registering a bunch of callbacks and errbacks' do
    before do
      @callsback = []
      @errsback = []

      subject.
        callback { @callsback << 'called' }.
        callback {|result| @callsback << result }.
        errback { @errsback << 'errored' }.
        errback {|error| @errsback << error }
    end

    describe 'on success' do
      before { subject.succeed :yay }

      it 'should call all the callbacks' do
        @callsback.should == ['called', :yay]
      end

      it 'should call none of the errbacks' do
        @errsback.should be_empty
      end
    end

    describe 'on failure' do
      before { subject.fail :boo }

      it 'should call none of the callbacks' do
        @callsback.should be_empty
      end

      it 'should call all the errbacks' do
        @errsback.should == ['errored', :boo]
      end
    end
  end

  describe '#safe_callback' do
    describe 'DG::success("bar").safe_callback{ |arg| raise "foo#{arg}" }' do
      subject{ DG::success("bar").safe_callback{ |arg| raise "foo#{arg}" } }

      it 'should not raise an exception' do
        lambda{ subject }.should_not raise_error
      end

      it 'should fail with foobar' do
        subject.should fail_with /foobar/
      end
    end
  end

  describe '#safe_errback' do
    describe 'DG::failure(ArgumentErrror.new("bar")).safe_errback{ |err| raise "foo#{err.message}" }' do
      subject{ DG::failure(ArgumentError.new("bar")).safe_errback{ |err| raise "foo#{err.message}" } }
      it 'should not raise an exception' do
        lambda{ subject }.should_not raise_error
      end

      it 'should fail with foobar' do
        subject.should fail_with /foobar/
      end
    end
  end
end
