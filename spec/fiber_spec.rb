require 'spec_helper'

describe LSpace do
  it "should be preserved across Fiber resumes" do
    LSpace.with(:foo => 2) do
      $fiber = Fiber.new do
        $foo = LSpace[:foo]
      end
    end
    $fiber.resume
    $foo.should == 2
  end
end
