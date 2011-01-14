require 'eventmachine'
require 'em/deferrable'


shared_examples_for 'a Deferrable' do
  it { should respond_to(:callback) }
  it { should respond_to(:errback) }
end


shared_examples_for 'a launchable task' do
  it 'should have a #go method to launch it' do
    should respond_to(:go)
  end
end


class RSpec::Core::ExampleGroup
  def self.it_should_include(mod)
    it "should include #{mod}" do
      described_class.included_modules.should include(mod)
    end
  end
end


module SpecTools
  # Simulates an async database API.
  #
  # Uses a hypothetical query language: e.g.
  #   query(:id, :name => "Sam")        # => 42
  #   query(:age, :location, :id => 42) # => [26, 'San Francisco']
  class DummyDB
    class << self
      # Run a query asynchronously.  Will report result via a Deferrable.
      def query(*query_parts)
        # N.B. default impl never succeeds or fails: call stub_*_query first
        # if you want to test that.
        EM::DefaultDeferrable.new
      end

      def stub_successful_query(*args)
        stub(:query).with(*args).and_return do
          DG.const(yield).
            tap(&:go)       # TODO
        end
      end

      def stub_failing_query(*args)
        stub(:query).with(*args).and_return do
          DG.failure(yield).
              tap(&:go)     # TODO
          end
      end
    end
  end

  class ResultReceiver
    attr_reader :result

    def has_result?; @has_result; end

    def result_is?(value)
      result_satisfies? {|result| result == value }
    end

    def result_satisfies?(&block)
      has_result? && yield(result)
    end

    def result=(result)
      @result = result
      @has_result = true
    end

    def to_proc
      proc &method(:result=)
    end
  end
end


RSpec::Matchers.define :succeed_with do |value|
  match do |deferrable|
    @callback = SpecTools::ResultReceiver.new
    deferrable.callback(&@callback)
    @errback = SpecTools::ResultReceiver.new
    deferrable.errback(&@errback)

    !@errback.has_result? && @callback.result_is?(value)
  end

  failure_message_for_should do |deferrable|
    failure = if @callback.has_result?
                "succeeded with #{@callback.result.inspect}"
              elsif @errback.has_result?
                "failed with #{@errback.result.inspect}"
              else
                "did not succeed"
              end
    "expected #{deferrable.inspect} to succeed with #{value.inspect}, but #{failure}"
  end
end


RSpec::Matchers.define :fail_with do |class_or_message, *message_or_empty|
  match do |deferrable|
    case class_or_message
    when Class
      @expected_class = class_or_message
      @expected_message = message_or_empty.empty? ? nil : message_or_empty[0]
    else
      @expected_message = class_or_message
    end

    @callback = SpecTools::ResultReceiver.new
    deferrable.callback(&@callback)
    @errback = SpecTools::ResultReceiver.new
    deferrable.errback(&@errback)

    @errback.result_satisfies? do |result|
      if @expected_class && !result.is_a?(@expected_class)
        @class_failure = "expected #{@expected_class} but got #{result.class}"
      end
      if @expected_message && !@expected_message.match(result.message)
        @message_failure = "expected message #{@expected_message.inspect} but got #{result.message.inspect}"
      end

      !@callback.has_result? && !(@class_failure || @message_failure)
    end
  end

  failure_message_for_should do |deferrable|
    if @errback.has_result?
      "#{deferrable.inspect} failed in the wrong way: #{[@class_failure, @message_failure].compact.join(', ')}"
    else
      failure = if @callback.has_result?
                  "succeeded with #{@callback.result.inspect}"
                else
                  "did not fail"
                end
      "expected #{deferrable.inspect} to fail with #{[@expected_class, @expected_message].compact.map(&:inspect).join(': ')}, but #{failure}"
    end
  end
end
