require 'spec_helper'

describe LSpace do
  it "should act like a hash" do
    LSpace[:foo] = 1
    LSpace[:foo].should == 1
  end

  it "should isolate changes to nested spaces" do
    LSpace[:foo] = 2

    LSpace.update :foo => 1 do
      LSpace[:foo].should == 1
    end

    LSpace[:foo].should == 2
  end

  it "should fallback to outer spaces" do
    LSpace[:bar] = 1
    LSpace.update do
      LSpace[:bar].should == 1
    end
  end

  it "should be isolated between different threads" do
    LSpace[:foo] = 1
    Thread.new{ LSpace[:foo].should == nil }.join
  end

  it "should be isolated between different fibers" do
    LSpace[:foo] = 1
    Fiber.new{ LSpace[:foo].should == nil }.resume
  end

  it "should allow preserving spaces" do
    p = LSpace.update(:foo => 1){ proc{ LSpace[:foo] }.in_lspace }
    p.call.should == 1
  end

  it "should allow resuming spaces in different threads" do
    p = LSpace.update(:foo => 1){ proc{ LSpace[:foo] }.in_lspace }
    Thread.new{ p.call.should == 1 }.join
  end

  it "should allow resuming spaces in different fibers" do
    p = LSpace.update(:foo => 1){ LSpace.preserve{ LSpace[:foo] } }
    Fiber.new{ p.call.should == 1 }.resume
  end

  it "should clean up lspace after resuming" do
    p = LSpace.update(:foo => 1){ proc{ LSpace[:foo] }.in_lspace }
    p.call.should == 1
    LSpace[:foo].should == nil
  end

  it "should resume the entire nested lspace" do
    p = LSpace.update(:foo => 1) {
          LSpace.update(:bar => 2) {
            LSpace.update(:baz => 3) {
              lambda &LSpace.preserve{ LSpace[:foo] + LSpace[:bar] + LSpace[:baz] }
            }
          }
        }

    p.call.should == 6
  end

  it "should return to enclosing lspace after re-entering new lspace" do
    LSpace.new(:baz => 1) do
      p = LSpace.update(:baz => 2){ proc{ LSpace[:baz] }.in_lspace }
      p.call.should == 2
      LSpace[:baz].should == 1
    end
  end

  it "should clean up lspaces properly even if an exception is raised" do
    LSpace.update(:baz => 1) do
      begin
        LSpace.update(:baz => 1) do
          raise "OOPS"
        end
      rescue => e
        LSpace[:baz].should == 1
      end
    end
  end
end
