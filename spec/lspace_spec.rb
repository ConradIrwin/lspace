require 'spec_helper'

describe LSpace do
  describe "with an implicit LSpace" do
    around do |example|
      LSpace.with({:foo => 1}) do
        example.run
      end
    end

    describe "#[]" do
      it "should act like a hash" do
        LSpace.current[:foo].should == 1
        LSpace.current.heirarchy_depth_for_key[:foo] = 1
      end

      it "should fall back to the parent" do
        lspace2 = LSpace.new({:bar => 2}, LSpace.current)
        lspace2[:foo].should == 1
        lspace2.heirarchy_depth_for_key[:foo].should == 1
      end

      it "should use the child in preference to the parent" do
        lspace2 = LSpace.new({:foo => 2}, LSpace.current)
        lspace2[:foo].should == 2
        lspace2.heirarchy_depth_for_key[:foo] = 2
      end

      it "can handle an unknown key" do
        LSpace.current[:unknown].should be_nil
        LSpace.current.heirarchy_depth_for_key[:unknown].should == LSpace::MISSING_KEY
      end
    end

    describe "#[]=" do
      it "should act like a hash" do
        LSpace.current[:foo] = 7
        LSpace.current[:foo].should == 7
      end

      it "should not affect the parent" do
        LSpace.with do
          LSpace.current[:foo] = 7
        end
        LSpace.current[:foo].should == 1
      end

      it "does not allow modifying a LSpace you aren't in" do
        expect do
          LSpace.with(value: 1) do
            LSpace.current.parent[:foo] = 2
          end
        end.to raise_error(ArgumentError, "You cannot modify a LSpace you are not currently inside of.")
      end
    end

    describe "#enter" do
      it "should delegate to LSpace" do
        LSpace.should_receive(:enter).once.with(LSpace.current)
        LSpace.current.enter do
          5 + 5
        end
      end
    end

    describe "#wrap" do
      it "should cause the LSpace to be entered when the block is called" do
        LSpace.current.wrap{ LSpace.current.should == LSpace.current }.call
      end

      it "should revert the changed LSpace at the end of the block" do
        lspace = LSpace.current
        LSpace.current.wrap{ LSpace.current.should == LSpace.current }.call
        LSpace.current.should == lspace
      end

      it "should be possible to call the block on a different thread" do
        todo = LSpace.current.wrap{ LSpace.current.should == LSpace.current }
        Thread.new{ todo.call }.join
      end
    end

    describe "#keys" do
      it "should return keys in the current LSpace" do
        LSpace.current.keys.should == [:foo]
      end

      it "should return keys from the parents" do
        child = LSpace.new({:bar => 7}, LSpace.current)
        child.keys.should == [:bar, :foo]
      end

      it "should not contain duplicates" do
        child = LSpace.new({:foo => 7}, LSpace.current)
        LSpace.current.keys.should == [:foo]
      end
    end
  end

  describe "#around_filter" do
    before do
      @entered = 0
      @returned = 0

      @lspace = LSpace.new({}, LSpace.current)

      @lspace.around_filter do |&block|
        @entered += 1
        begin
          block.call
        ensure
          @returned += 1
        end
      end
    end

    it "should be run when the LSpace is entered" do
      LSpace.enter @lspace do
        @entered.should == 1
        @returned.should == 0
      end
      @returned.should == 1
    end

    it "should not be run when the LSpace is re-entered" do
      LSpace.enter @lspace do
        LSpace.enter @lspace do
          @entered.should == 1
        end
      end
    end

    it "should not be re-run when a child of the LSpace is entered" do
      lspace2 = LSpace.new({}, LSpace.current)

      LSpace.enter @lspace do
        lspace2.enter do
          @entered.should == 1
        end
      end
    end

    it "should apply around_filters from first to last" do
      called = []
      
      @lspace.around_filter do |&block|
        called << :first
        block.call
      end
      @lspace.around_filter do |&block|
        called << :last
        block.call
      end

      LSpace.enter @lspace do
        called.should == [:first, :last]
      end
    end

    it "should apply around_filters from parents before children" do
      called = []
      @lspace.around_filter do |&block|
        called << :first
        block.call
      end
      lspace2 = LSpace.new({}, @lspace)
      lspace2.around_filter do |&block|
        called << :last
        block.call
      end

      LSpace.enter lspace2 do
        called.should == [:first, :last]
      end
    end
  end

  describe "#hierarchy" do
    it "should return [self] if there is no parent" do
      LSpace.current.hierarchy.should == [LSpace.current]
    end

    it "should return the full list if there are parents" do
      l1 = LSpace.new({}, LSpace.current)
      l2 = LSpace.new({}, l1)

      l2.hierarchy.should == [l2, l1, LSpace.current]
    end
  end
end
