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

  describe ".update" do
    it "should enter a new LSpace with the new variables set" do
      LSpace.update(:foo => 5) do
        LSpace[:foo].should == 5
      end
    end

    it "should enter a new LSpace which delegates to the current parent" do
      LSpace.update(:foo => 5) do
        LSpace.update(:bar => 4) do
          LSpace[:foo].should == 5
        end
      end
    end
  end

  describe ".clean" do
    it "should enter a new LSpace with no parent" do
      LSpace.update(:foo => 5) do
        LSpace.clean do
          LSpace[:foo].should == nil
        end
      end
    end
  end

  describe ".enter" do
    it "should update LSpace.current" do
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

    it "should not effect other fibers" do
      LSpace.enter(@lspace) do
        Fiber.new{ LSpace.current.should_not == @lspace }.resume
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
