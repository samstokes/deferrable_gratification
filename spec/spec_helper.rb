require 'eventmachine'
require 'em/deferrable'


shared_examples_for 'a Deferrable' do
  it { should respond_to(:callback) }
  it { should respond_to(:errback) }
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
        stub(:query).with(*args).and_return { DG.const(yield) }
      end

      def stub_failing_query(*args)
        stub(:query).with(*args).and_return { DG.failure(yield) }
      end
    end
  end


  class Callback
    def called?() @called end
    attr_reader :result

    def has_result?; @has_result; end

    def initialize() @called = @has_result = false end

    def result_description
      if called?
        if has_result?
          result.inspect
        else
          '#<no result>'
        end
      else
        '#<not called>'
      end
    end

    def result_is?(value)
      result_satisfies? {|result| result == value }
    end

    def result_satisfies?(&block)
      called? && has_result? && yield(result)
    end

    def call(*values)
      @called = true

      case values.size
      when 0
        # don't set result
      when 1
        self.result = values[0]
      else
        self.result = values
      end
    end

    def to_proc
      lambda {|*values| self.call(*values) }
    end

    # TODO delete me, I was a bad idea
    #def to_proc
    #  # Want to just say lambda &method(:result=), but that seems to have a
    #  # weird bug: if the resulting proc gets called with an empty array [],
    #  # it destructures the array and complains of being called with 0 args.
    #  # It doesn't do the same for a nonempty array (i.e. called with [1] it
    #  # receives [1] not 1).
    #  lambda {|value| self.result = value }
    #end

    private
    def result=(result)
      @result = result
      @has_result = true
    end
  end
end


DummyDB = SpecTools::DummyDB


RSpec::Matchers.define :succeed_with do |*values_or_empty|
  case values_or_empty.size
  when 0
    @cares_about_value = false
  else
    @cares_about_value = true
    @values = values_or_empty
  end

  match do |deferrable|
    @callback = SpecTools::Callback.new
    deferrable.callback(&@callback)

    @errback = SpecTools::Callback.new
    deferrable.errback(&@errback)

    !@errback.called? && @callback.called? && (
      if @cares_about_value
        @callback.result_satisfies? do |*results|
          @values.zip(results).each do |(value, result)|
            if value.respond_to? :match
              value.match(result)
            else
              value == result
            end
          end
        end
      else
        true
      end)
  end

  def description
    @cares_about_value ? super : 'succeed'
  end

  def expectation_description
    if @cares_about_value
      "succeed with #{@values.map(&:inspect).join(", ")}"
    else
      'succeed'
    end
  end

  failure_message_for_should do |deferrable|
    failure = if @callback.called?
                "succeeded with #{@callback.result_description}"
              elsif @errback.called?
                "failed with #{@errback.result_description}"
              else
                'did not succeed'
              end
    "expected #{deferrable.inspect} to #{expectation_description}, but #{failure}"
  end

  failure_message_for_should_not do |deferrable|
    "expected #{deferrable.inspect} not to #{expectation_description}, but did succeed with #{@callback.result_description}"
  end
end


RSpec::Matchers.define :fail_with do |*class_and_or_message_or_empty|
  match do |deferrable|
    case class_and_or_message_or_empty.size
    when 0
      @cares_about_value = false
    when 1
      @cares_about_value = true
      class_or_message = class_and_or_message_or_empty[0]
      if class_or_message.is_a? Class
        @expected_class = class_or_message
      else
        @expected_message = class_or_message
      end
    when 2
      @cares_about_value = true
      @expected_class, @expected_message = class_and_or_message_or_empty
    else
      raise ArgumentError, 'too many arguments to fail_with'
    end

    @callback = SpecTools::Callback.new
    deferrable.callback(&@callback)
    @errback = SpecTools::Callback.new
    deferrable.errback(&@errback)

    !@callback.called? && @errback.called? && (
      if @cares_about_value
        @errback.result_satisfies? do |result|
          if @expected_class && !result.is_a?(@expected_class)
            @class_failure = "expected #{@expected_class} but got #{result.class}"
          end
          if @expected_message && !@expected_message.match(result.message)
            @message_failure = "expected message #{@expected_message.inspect} but got #{result.message.inspect}"
          end

          !(@class_failure || @message_failure)
        end
      else
        true
      end)
  end

  def description
    @cares_about_value ? super : 'fail'
  end

  def error_expectation_description
    if @cares_about_value
      'fail with ' + [@expected_class, @expected_message].compact.map(&:inspect).join(': ')
    else
      'fail'
    end
  end

  failure_message_for_should do |deferrable|
    if @errback.called?
      "#{deferrable.inspect} failed in the wrong way: #{[@class_failure, @message_failure].compact.join(', ')}"
    else
      failure = if @callback.called?
                  "succeeded with #{@callback.result_description}"
                else
                  "did not fail"
                end
      "expected #{deferrable.inspect} to #{error_expectation_description}, but #{failure}"
    end
  end

  failure_message_for_should_not do |deferrable|
    "expected #{deferrable.inspect} not to #{error_expectation_description}, but did fail with #{@errback.result_description}"
  end
end


module RSpec::Matchers
  # Assert failure or success without specifying the callback params (because
  # 'should succeed_with;' is clunky)
  alias succeed_with_anything succeed_with
  alias fail_with_anything fail_with
end
