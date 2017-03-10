require 'spec_helper'
describe LSpace do
  before do
    @lspace = LSpace.new({}, nil)
  end

  describe ".current" do
    it "should return the most recently entered LSpace" do
      LSpace.enter @lspace do
        LSpace.current.should == @lspace
      end
    end

    it "should ignore changes on other threads" do
      LSpace.enter @lspace do
        Thread.new{ LSpace.current.should_not == @lspace }.join
      end
    end
  end

  describe ".with" do
    it "should enter a new LSpace with the new variables set" do
      LSpace.with(:foo => 5) do
        LSpace[:foo].should == 5
      end
    end

    it "should enter a new LSpace which delegates to the current parent" do
      LSpace.with(:foo => 5) do
        LSpace.with(:bar => 4) do
          LSpace[:foo].should == 5
        end
      end
    end
  end

  describe ".clean" do
    it "should enter a new LSpace with no parent" do
      LSpace.with(:foo => 5) do
        LSpace.clean do
          LSpace[:foo].should == nil
        end
      end
    end
  end

  describe ".enter" do
    it "should with LSpace.current" do
      LSpace.enter(@lspace) do
        LSpace.current.should == @lspace
      end
    end

    it "should revert that change at the end of the block" do
      lspace = LSpace.current
      LSpace.enter(@lspace) do
        # yada yada
      end
      LSpace.current.should == lspace
    end

    it "should revert that change even if the block raises an exception" do
      lspace = LSpace.current
      lambda do
        LSpace.enter(@lspace) do
          raise "OOPS"
        end
      end.should raise_error /OOPS/
      LSpace.current.should == lspace
    end

    it "should not effect other threads" do
      LSpace.enter(@lspace) do
        Thread.new{ LSpace.current.should_not == @lspace }.join
      end
    end
  end

  describe ".fork" do
    it "should not propagate variable changes to the parent LSpace" do
      LSpace.enter(@lspace) do
        LSpace.fork
        LSpace[:foo] = 5
        LSpace[:foo].should == 5
      end
      @lspace[:foo].should be_nil
    end

    it "should show the new forked LSpace to around_filters after returning" do
      @lspace.around_filter do |&block|
        LSpace[:foo].should == 4
        block.call
        LSpace[:foo].should == 5
      end
      @lspace[:foo] = 4
      @lspace.enter do
        LSpace.fork
        LSpace[:foo] = 5
      end
    end
  end

  describe ".preserve" do
    it "should delegate to LSpace.current" do
      LSpace.current.should_receive(:wrap).once
      LSpace.preserve{ 5 }
    end
  end

  describe ".[]" do
    it "should delegate to LSpace.current" do
      LSpace.current.should_receive(:[]).once.with(:foo).and_return(:bar)
      LSpace[:foo].should == :bar
    end
  end

  describe ".[]=" do
    it "should delegate to LSpace.current" do
      LSpace.current.should_receive(:[]=).once.with(:foo, :bar)
      LSpace[:foo] = :bar
    end
  end

  describe ".around_filter" do
    it "should delegate to LSpace.current" do
      @lspace.should_receive(:around_filter).once
      LSpace.enter @lspace do
        LSpace.around_filter do |&block|
          block.call
        end
      end
    end
  end
end
