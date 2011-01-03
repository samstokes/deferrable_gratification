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
