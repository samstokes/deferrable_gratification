require 'deferrable_gratification'

# N.B. most of these specs rely on the fact that all the example functions and
# callbacks used are synchronous, because testing the results of asynchronous
# code in RSpec is hard.  (Testing that a callback is called with the right
# value is easy; testing that it is called at all is harder.)
#
# However, the combinators should work just fine for asynchronous operations,
# or for a mixture of synchronous and asynchronous.

describe DeferrableGratification::Combinators do
  describe '#>>' do
    describe 'DummyDB.query(:id, :name => "Sam") >> lambda {|id| DummyDB.query(:age, :id => id) }' do
      subject { DummyDB.query(:id, :name => "Sam") >> lambda {|id| DummyDB.query(:age, :id => id) } }

      before do
        DummyDB.stub_successful_query(:id, :name => "Sam") { 42 }
        DummyDB.stub_successful_query(:age, :id => 42) { 26 }
      end

      it { should succeed_with 26 }
    end

    describe 'DummyDB.query(:id, :name => :nonexistent) >> lambda {|id| DummyDB.query(:age, :id => id) }' do
      subject { DummyDB.query(:id, :name => :nonexistent) >> lambda {|id| DummyDB.query(:age, :id => id) } }

      before { DummyDB.stub_failing_query(:id, :name => :nonexistent) { 'No such user' } }

      it { should fail_with 'No such user' }
    end

    describe 'DummyDB.query(:name, :id => 42) >> lambda {|name| "Hello #{name}!" }' do
      subject { DummyDB.query(:name, :id => 42) >> lambda {|name| "Hello #{name}!" } }

      before { DummyDB.stub_successful_query(:name, :id => 42) { 'Sam' } }

      it { should succeed_with 'Hello Sam!' }
    end

    describe 'DummyDB.query(:id, :name => "Sam") >> lambda {|id| raise "User #{id} not allowed!" }' do
      subject { DummyDB.query(:id, :name => "Sam") >> lambda {|id| raise "User #{id} not allowed!" } }

      before { DummyDB.stub_successful_query(:id, :name => 'Sam') { 42 } }

      it { should fail_with 'User 42 not allowed!' }
    end
  end


  describe '#transform' do
    let(:operation) { DG::DefaultDeferrable.new }

    describe 'operation.transform(&:upcase)' do
      subject { operation.transform(&:upcase) }

      describe 'if the operation succeeds with "Hello"' do
        before { operation.succeed('Hello') }
        it { should succeed_with('HELLO') }
      end

      describe 'if the operation fails with "bad robot"' do
        before { operation.fail(RuntimeError.new('bad robot')) }
        it { should fail_with('bad robot') }
      end
    end

    describe 'operation.transform { raise "kaboom!" }' do
      subject { operation.transform { raise "kaboom!" } }

      describe 'if the operation succeeds' do
        before { operation.succeed }

        it 'should catch the exception' do
          lambda { subject }.should_not raise_error(/kaboom/)
        end

        it 'should fail and pass through the exception' do
          subject.should fail_with(RuntimeError, /kaboom!/)
        end
      end
    end

    describe '@results = []; operation.transform(&@results.method(:<<))' do
      before do
        @results = []
        operation.transform(&@results.method(:<<))
      end

      describe 'if operation succeeds with :wahey!' do
        before { operation.succeed :wahey! }

        it 'should add :wahey! to @results' do
          @results.should == [:wahey!]
        end
      end

      describe 'if operation fails' do
        before { operation.fail RuntimeError.new('Boom!') }

        it 'should not touch @results' do
          @results.should be_empty
        end
      end
    end

    describe 'when the return value of the block happens to be a Deferrable' do
      before do
        @result = EM::DefaultDeferrable.new
      end

      subject { operation.transform { @result } }

      it "should succeed with the return value itself, not wait for the return value's callback" do
        operation.succeed :test
        subject.should succeed_with(@result)
      end
    end
  end


  describe '#transform_error' do
    let(:operation) { DG::DefaultDeferrable.new }

    describe 'operation.transform_error {|msg| RuntimeError.new(msg) }' do
      subject { operation.transform_error {|msg| RuntimeError.new(msg) } }

      describe 'if the operation succeeds with "Hello"' do
        before { operation.succeed('Hello') }
        it { should succeed_with('Hello') }
      end

      describe 'if the operation fails with the string "bad robot"' do
        before { operation.fail('bad robot') }
        it { should fail_with(RuntimeError, 'bad robot') }
      end
    end

    describe 'operation.transform_error { raise "kaboom!" }' do
      subject { operation.transform_error { raise "kaboom!" } }

      describe 'if the operation succeeds' do
        before { operation.succeed 'Hello' }
        it { should succeed_with 'Hello' }
      end

      describe 'if the operation fails' do
        before { operation.fail 'bad robot' }

        it 'should catch the exception' do
          lambda { subject }.should_not raise_error(/kaboom/)
        end

        it 'should fail and pass through the exception' do
          subject.should fail_with(RuntimeError, /kaboom!/)
        end
      end
    end

    describe '@errors = []; operation.transform_error(&@errors.method(:<<))' do
      before do
        @errors = []
        operation.transform_error(&@errors.method(:<<))
      end

      describe 'if operation succeeds with :wahey!' do
        before { operation.succeed :wahey! }

        it 'should not touch @errors' do
          @errors.should be_empty
        end
      end

      describe 'if operation fails' do
        before { operation.fail RuntimeError.new('Boom!') }

        it 'should add RuntimeError("Boom!") to @errors' do
          @errors.first.should be_a RuntimeError
          @errors.first.message.should == 'Boom!'
        end
      end
    end
  end


  describe '#bind!' do
    describe 'DummyDB.query(:id, :name => "Sam").bind! {|id| DummyDB.query(:location, :id => id) }' do
      def bind!() DummyDB.query(:id, :name => "Sam").bind! {|id| DummyDB.query(:location, :id => id) } end

      describe 'if first query succeeds with id 42' do
        before { DummyDB.stub_successful_query(:id, :name => 'Sam') { 42 } }

        it 'should pass id 42 to the second query' do
          DummyDB.should_receive(:query).with(:location, :id => 42)
          bind!
        end

        describe 'if the second query succeeds with "San Francisco"' do
          before { DummyDB.stub_successful_query(:location, :id => 42) { 'San Francisco' } }

          describe 'return value' do
            subject { bind! }

            it { should succeed_with 'San Francisco' }
          end
        end

        describe 'if the second query fails with "no location found"' do
          before { DummyDB.stub_failing_query(:location, :id => 42) { 'no location found' } }

          describe 'return value' do
            subject { bind! }

            it { should fail_with 'no location found' }
          end
        end
      end

      describe 'if first query fails' do
        before { DummyDB.stub_failing_query(:id, :name => 'Sam') { 'user Sam not found' } }

        it 'should not run the second query' do
          DummyDB.should_not_receive(:query).with(:location, :id => anything())
          bind!
        end
      end
    end

    describe 'DummyDB.query(:id, :name => "Sam").bind! {|id| raise "id #{id} not authorised" }' do
      let(:first_query) { DummyDB.query(:id, :name => "Sam") }
      def bind!() first_query.bind! {|id| raise "id #{id} not authorised" } end

      describe 'if first query succeeds with id 42' do
        before { DummyDB.stub_successful_query(:id, :name => 'Sam') { 42 } }

        it 'should not stop the first query from succeeding (in case other code subscribed to it)' do
          bind!
          first_query.should succeed_with(42)
        end
      end

    end
  end


  describe '#guard' do
    let(:operation) { DG::DefaultDeferrable.new }

    describe 'operation.guard("must be even", &:even?)' do
      subject { operation.guard("must be even", &:even?) }

      describe 'if the operation succeeds with 300' do
        before { operation.succeed(300) }
        it { should succeed_with(300) }
      end

      describe 'if the operation succeeds with 317' do
        before { operation.succeed(317) }
        it { should fail_with(DG::GuardFailed, /must be even/) }
        it { should fail_with(DG::GuardFailed, /317/) }
      end

      describe 'if the operation fails with "bad robot"' do
        before { operation.fail(RuntimeError.new('bad robot')) }
        it { should fail_with('bad robot') }
      end
    end

    describe 'operation.guard("must have job") {|person| person[:job] }.guard("must have title") {|person| person[:job][:title] }' do
      # note that the job title block can raise NoMethodError
      subject { operation.guard("must have job") {|person| person[:job] }.guard("must have title") {|person| person[:job][:title] } }

      describe 'if the operation succeeds with {:name => "Sam"}' do
        before { operation.succeed :name => "Sam" }

        it 'should not raise an exception' do
          lambda { subject }.should_not raise_error
        end
        it { should_not fail_with(NoMethodError) }
        it { should fail_with(DG::GuardFailed, /job/) }
      end

      describe 'if the operation succeeds with {:job => {:company => "Rapportive"}}' do
        before { operation.succeed :job => {:company => "Rapportive"} }

        it { should fail_with(DG::GuardFailed, /title/) }
      end

      describe 'if the operation succeeds with {:job => {:title => "CTO", :company => "Rapportive"}}' do
        before { operation.succeed :job => {:title => "CTO", :company => "Rapportive"} }

        it { should succeed_with({:job => {:title => "CTO", :company => "Rapportive"}}) }
      end
    end

    describe 'operation.callback {|value| @results << value }.guard(&:even?).callback {|value| @even_results << value }' do
      before do
        @results = []
        @even_results = []

        operation.
          callback {|value| @results << value }.
          guard(&:even?).
          callback {|value| @even_results << value }
      end

      describe 'if the value passes the guard' do
        before { operation.succeed(300) }

        specify 'both callbacks should fire' do
          @results.should == [300]
          @even_results.should == [300]
        end
      end

      describe 'if the value fails the guard' do
        before { operation.succeed(301) }

        specify 'the first callback should fire' do
          @results.should == [301]
        end

        specify 'the second callback should not fire' do
          @even_results.should be_empty
        end
      end
    end

    describe 'operation.guard { raise "kaboom!" }' do
      subject { operation.guard { raise "kaboom!" } }

      describe 'if the operation succeeds' do
        before { operation.succeed }

        it 'should catch the exception' do
          lambda { subject }.should_not raise_error(/kaboom/)
        end

        it 'should fail and pass through the exception' do
          subject.should fail_with(RuntimeError, /kaboom!/)
        end
      end
    end
  end


  describe '.chain' do
    describe 'DG.chain()' do
      subject { DG.chain() }
      it { should succeed_with_anything }
    end

    describe 'DG.chain(lambda { 2 })' do
      subject { DG.chain(lambda { 2 }) }

      it { should succeed_with(2) }
    end

    describe <<-CHAIN do
DG.chain(
  lambda { DummyDB.query(:person_id, :name => 'Sam') },
  lambda {|person_id| DummyDB.query(:products, :buyer_id => person_id) },
  lambda {|products| DummyDB.query(:description, :product_id => products.map(&:id)) },
  lambda {|descriptions| descriptions.map(&:brief) })
    CHAIN
      subject do
        DG.chain(
          lambda { DummyDB.query(:person_id, :name => 'Sam') },
          lambda {|person_id| DummyDB.query(:products, :buyer_id => person_id) },
          lambda {|products| DummyDB.query(:description, :product_id => products.map(&:id)) },
          lambda {|descriptions| descriptions.map(&:brief) })
      end

      before do
        DummyDB.stub_successful_query(:person_id, :name => 'Sam') { 42 }
        DummyDB.stub_successful_query(:products, :buyer_id => 42) do
          [1, 2, 3].map {|id| mock('product', :id => id) }
        end
        DummyDB.stub_successful_query(:description, :product_id => [1, 2, 3]) do
          %w(Car Dishwasher Laptop).map {|brief| mock('description', :brief => brief) }
        end
      end

      it { should succeed_with ['Car', 'Dishwasher', 'Laptop'] }
    end

    describe <<-CHAIN do
DG.chain(
  lambda { DummyDB.query(:person_id, :name => :nonexistent) },
  lambda {|person_id| DummyDB.query(:products, :buyer_id => person_id) },
  lambda {|products| DummyDB.query(:description, :product_id => products.map(&:id)) },
  lambda {|descriptions| descriptions.map(&:brief) })
    CHAIN
      subject do
        DG.chain(
          lambda { DummyDB.query(:person_id, :name => :nonexistent) },
          lambda {|person_id| DummyDB.query(:products, :buyer_id => person_id) },
          lambda {|products| DummyDB.query(:description, :product_id => products.map(&:id)) },
          lambda {|descriptions| descriptions.map(&:brief) })
      end

      before { DummyDB.stub_failing_query(:person_id, :name => :nonexistent) { 'No such person' } }

      it { should fail_with('No such person') }
    end
  end


  describe '.join_successes' do
    describe 'DG.join_successes()' do
      subject { DG.join_successes() }
      it { should succeed_with [] }
    end

    describe 'DG.join_successes(first, second)' do
      let(:first) { EM::DefaultDeferrable.new }
      let(:second) { EM::DefaultDeferrable.new }
      subject { DG.join_successes(first, second) }

      it 'should not succeed or fail' do
        subject.should_not succeed_with_anything
        subject.should_not fail_with_anything
      end

      describe 'after first succeeds with :one' do
        before { first.succeed :one }

        it 'should not succeed or fail' do
          subject.should_not succeed_with_anything
          subject.should_not fail_with_anything
        end

        describe 'after second succeeds with :two' do
          before { second.succeed :two }

          it { should succeed_with [:one, :two] }
        end

        describe 'after second fails' do
          before { second.fail 'oops' }

          it { should succeed_with [:one] }
        end
      end

      describe 'after both fail' do
        before { first.fail 'oops'; second.fail 'oops' }

        it { should succeed_with [] }
      end

      describe 'preserving order of operations' do
        describe 'if second succeeds before first does' do
          subject do
            DG.join_successes(first, second).tap do |successes|
              second.succeed :two
              first.succeed :one
            end
          end
          it 'should still succeed with [:one, :two]' do
            subject.should succeed_with [:one, :two]
          end
        end
      end
    end
  end


  describe '.join_first_success' do
    describe 'DG.join_first_success()' do
      subject { DG.join_first_success() }
      it { should_not succeed_with_anything }
    end

    describe 'DG.join_first_success(first, second)' do
      let(:first) { EM::DefaultDeferrable.new }
      let(:second) { EM::DefaultDeferrable.new }
      subject { DG.join_first_success(first, second) }

      it 'should not succeed or fail' do
        subject.should_not succeed_with_anything
        subject.should_not fail_with_anything
      end

      describe 'after first succeeds with :one' do
        before { first.succeed :one }

        it { should succeed_with :one }

        describe 'after second succeeds with :two' do
          before { second.succeed :two }

          it 'should still succeed with :one' do
            subject.should succeed_with :one
          end
        end

        describe 'after second fails' do
          before { second.fail 'oops' }

          it 'should still succeed with :one' do
            subject.should succeed_with :one
          end
        end
      end

      describe 'after second succeeds with :two' do
        before { second.succeed :two }

        it { should succeed_with :two }
      end

      describe 'after first fails' do
        before { first.fail 'oops' }

        it 'should not succeed or fail' do
          subject.should_not succeed_with_anything
          subject.should_not fail_with_anything
        end

        describe 'after second succeeds with :two' do
          before { second.succeed :two }

          it { should succeed_with :two }
        end

        describe 'after second also fails' do
          before { second.fail 'oops' }

          it 'should not succeed or fail' do
            subject.should_not succeed_with_anything
            subject.should_not fail_with_anything
          end
        end
      end
    end
  end


  describe '.loop_until_success' do
    {
      'in EventMachine' => lambda do |ui|
        d = nil
        EM.run do
          d = DG.loop_until_success { ui.wait_for_click(1) }.
            bothback { EM.stop }.
            tap {|l| l.timeout(1) } # stop tests hanging forever if we screw up
        end
        d
      end,
      'outside EventMachine' => lambda do |ui|
        DG.loop_until_success { ui.wait_for_click(1) }
      end,
    }.each do |env, do_loop|
      describe env do
        describe 'DG.loop_until_success { ui.wait_for_click(1) }' do
          subject { do_loop.call(ui) }
          let(:ui) do
            double().tap do |ui|
              ui.stub!(:wait_for_click) { EM::DefaultDeferrable.new.tap(&:succeed) }
            end
          end

          it 'should call ui.wait_for_click at least once' do
            ui.should_receive(:wait_for_click)
            do_loop.call(ui)
          end

          describe 'if the user already clicked' do
            before { ui.stub!(:wait_for_click) { DG.const(:click!)} }

            it { should succeed_with(:click!) }

            it 'should not call ui.wait_for_click again' do
              ui.should_receive(:wait_for_click).at_most(1)
              do_loop.call(ui)
            end
          end

          describe 'if ui.wait_for_click throws an exception' do
            before { ui.stub!(:wait_for_click).and_raise('User eaten by weasel') }

            it { should fail_with('User eaten by weasel') }

            it 'should not call ui.wait_for_click again' do
              ui.should_receive(:wait_for_click).at_most(1)
              do_loop.call(ui)
            end
          end

          describe 'if the user takes 4 seconds to click' do
            before do
              @attempts = 0
              ui.stub!(:wait_for_click) do
                @attempts += 1
                if @attempts >= 4
                  DG.const(:click!)
                else
                  DG.failure('1 second timeout')
                end
              end
            end

            it 'should try 4 times' do
              do_loop.call(ui)
              @attempts.should == 4
            end

            it { should succeed_with :click! }
          end
        end
      end
    end
  end
end
