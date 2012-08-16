require 'deferrable_gratification'

describe DeferrableGratification::Combinators do
  describe '.in_parallel' do

    describe 'with successful operations' do
      subject do
        DG.in_parallel(
          DummyDB.query(:id, :name => 'Sam'),
          DummyDB.query(:age, :id => 42)
        )
      end

      before do
        DummyDB.stub_successful_query(:id, :name => 'Sam') { 42 }
        DummyDB.stub_successful_query(:age, :id => 42) { 26 }
      end

      it "should succeed" do
        subject.should succeed_with [42, 26], []
      end
    end

    describe 'with a mix of operations' do
      subject do
        DG.in_parallel(
          DummyDB.query(:id, :name => 'Sam'),
          DummyDB.query(:age, :id => 42)
        )
      end

      before do
        DummyDB.stub_successful_query(:id, :name => 'Sam') { 42 }
        DummyDB.stub_failing_query(:age, :id => 42) { 'oops' }
      end

      it "should succeed" do
        subject.should succeed_with [42], ['oops']
      end
    end
  end
end
