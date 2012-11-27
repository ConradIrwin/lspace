require 'spec_helper'

describe LSpace do
  before do
    @lspace = LSpace.new({:foo => 1}, nil)
  end

  describe "#[]" do
    it "should act like a hash" do
      @lspace[:foo].should == 1
    end

    it "should fall back to the parent" do
      lspace2 = LSpace.new({:bar => 2}, @lspace)
      lspace2[:foo].should == 1
    end

    it "should use the child in preference to the parent" do
      lspace2 = LSpace.new({:foo => 2}, @lspace)
      lspace2[:foo].should == 2
    end
  end

  describe "#[]=" do
    it "should act like a hash" do
      @lspace[:foo] = 7
      @lspace[:foo].should == 7
    end

    it "should not affect the parent" do
      lspace2 = LSpace.new({}, @lspace)
      lspace2[:foo] = 7
      @lspace[:foo].should == 1
    end
  end

  describe "#around_filter" do
    before do
      @entered = 0
      @returned = 0

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
      lspace2 = LSpace.new({}, @lspace)

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

  describe "#enter" do
    it "should delegate to LSpace" do
      LSpace.should_receive(:enter).once.with(@lspace)
      @lspace.enter do
        5 + 5
      end
    end
  end

  describe "#wrap" do
    it "should cause the LSpace to be entered when the block is called" do
      @lspace.wrap{ LSpace.current.should == @lspace }.call
    end

    it "should revert the changed LSpace at the end of the block" do
      LSpace.current.should_not == @lspace
      lspace = LSpace.current
      @lspace.wrap{ LSpace.current.should == @lspace }.call
      LSpace.current.should == lspace
    end

    it "should be possible to call the block on a different thread" do
      todo = @lspace.wrap{ LSpace.current.should == @lspace }
      Thread.new{ todo.call }.join
    end
  end

  describe "#hierarchy" do
    it "should return [self] if there is no parent" do
      @lspace.hierarchy.should == [@lspace]
    end

    it "should return the full list if there are parents" do
      l1 = LSpace.new({}, @lspace)
      l2 = LSpace.new({}, l1)

      l2.hierarchy.should == [l2, l1, @lspace]
    end
  end
end
