require 'eventmachine'
require 'em/deferrable'

class MockDeferrable < EventMachine::DefaultDeferrable
  def stub_success!(*args)
    self.stub!(:go) { self.succeed(*args) }
  end

  def stub_failure!(*args)
    self.stub!(:go) { self.fail(*args) }
  end
end


shared_examples_for 'a Deferrable' do
  it { should respond_to(:callback) }
  it { should respond_to(:errback) }

  it 'should have a #go method to launch it' do
    should respond_to(:go)
  end
end
