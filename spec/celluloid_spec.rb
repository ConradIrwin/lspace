require 'spec_helper'

describe LSpace do
  it "should be preserved across sync calls" do
    seen = nil
    actor = Class.new do
      include Celluloid
      define_method(:update_seen) do
        seen = LSpace[:to_see]
      end
    end

    LSpace.with(:to_see => 5) {
      actor.new.update_seen
    }
    seen.should == 5
  end

  it "should be preserved across async calls" do
    seen = nil
    actor = Class.new do
      include Celluloid
      define_method(:update_seen) do
        seen = LSpace[:to_see]
      end
    end

    LSpace.with(:to_see => 7) {
      actor.new.async.update_seen
    }
    sleep 0.1 # TODO, actor.join or equivalent?
    seen.should == 7
  end

  it "should be preserved across async calls" do
    seen = nil
    actor = Class.new do
      include Celluloid
      define_method(:update_seen) do
        seen = LSpace[:to_see]
      end
    end

    LSpace.with(:to_see => 7) {
      f = actor.new.future.update_seen
      f.value
    }
    seen.should == 7
  end
end
