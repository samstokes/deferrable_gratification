require 'deferrable_gratification'

describe DeferrableGratification::Combinators do
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

  describe '.loop_until_failure' do
    let(:resource) do
      double().tap do |resource|
        resource.stub!(:get) { raise "Invalid URI" }
      end
    end
    describe 'DG.loop_until_failure { resource.get("http//:tyop.com") }' do
      subject { DG.loop_until_failure { resource.get("http://:tyop.com") } }

      it 'should not raise an exception' do
        lambda { subject }.should_not raise_error
      end

      it { should fail_with(RuntimeError, /Invalid URI/) }

      it 'should call the block exactly once' do
        resource.should_receive(:get).once
        subject
      end
    end

    describe 'DG.loop_until_failure { resource.get(@page += 1) }' do
      before do
        @page = 0
        resource.stub!(:get) do |page|
          if page < 2
            DG::success "lots of data"
          else
            DG::failure(RuntimeError.new("No more pages"))
          end
        end
      end

      subject { DG.loop_until_failure{ resource.get(@page += 1) } }

      it { should fail_with(RuntimeError, /No more pages/) }

      it 'should call the block until there are no more pages' do
        resource.should_receive(:get).twice
        subject
      end
    end

    describe 'DG.loop_until_failure { resource.get(:slow, @page += 1) }' do
      before do
        @page = 0
        resource.stub!(:get) do |slow, page|
          DG::blank.tap do |result|
            EM::next_tick do
              if page < 3
                result.succeed "lots of data"
              else
                result.fail RuntimeError.new("No more pages")
              end
            end
          end
        end
      end

      subject do
        d = nil
        EM.run do
          d = DG.loop_until_failure { resource.get(:slow, @page += 1) }.
            bothback { EM.stop }.
            tap {|l| l.timeout(1) } # stop tests hanging forever if we screw up
        end
        d
      end

      it { should fail_with(RuntimeError, /No more pages/) }

      it 'should call the block until there are no more pages' do
        resource.should_receive(:get).exactly(3).times
        subject
      end
    end
  end

  describe '.loop_while' do
    before do
      @log = []
    end
    describe 'DG.loop_while(lambda{ false }){ @log << 1}' do
      subject { DG.loop_while(lambda{ false }){ @log << 1 } }

      it "should not call the loop ever" do
        subject
        @log.should == []
      end

      it{ should succeed_with(nil) }
    end

    describe 'DG.loop_while(lambda{ @log.length < 3 }){ @log << 1 }' do
      subject { DG.loop_while(lambda{ @log.length < 3 }){ @log << 1; DG::success("returnme#{@log.length}") } }

      it 'should call the loop three times' do
        subject
        @log.should == [1, 1, 1]
      end

      it{ should succeed_with("returnme3") }
    end

    describe 'DG.loop_while(lambda{ raise "condition" }){ raise "body" }' do
      subject { DG.loop_while(lambda{ raise "condition" }){ raise "body" } } 

      it 'should not raise an exception' do
        lambda{ subject }.should_not raise_error
      end

      it{ should fail_with("condition") }
    end

    describe 'DG.loop_while(lambda{ true }){ raise "body" }' do
      subject { DG.loop_while(lambda{ true }){ raise "body" } }

      it 'should not raise an exception' do
        lambda{ subject }.should_not raise_error
      end

      it{ should fail_with("body") }
    end

    describe 'DG.loop_while(lambda{ true }){ @log << 1; DG::failure(RuntimeError.new("foo")) }' do
      subject { DG.loop_while(lambda{ true }){ @log << 1; DG::failure(RuntimeError.new("foo")) } }

      it 'should call the loop once' do
        subject
        @log.should == [1]
      end

      it{ should fail_with(/foo/) }
    end

    describe 'DG.loop_while(lambda{ true }){ "not-a-deferrable" }' do
      subject{ DG.loop_while(lambda{ true }){ "not-a-deferrable" } }
      it{ should fail_with(NoMethodError) }
    end
  end
end
