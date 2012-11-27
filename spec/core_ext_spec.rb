require 'spec_helper'

describe Module do
  describe "#lspace_reader" do
    it "should define a reader for LSpace" do
      klass = Class.new{ lspace_reader :user_id }

      LSpace.update(:user_id => 8) do
        klass.new.user_id.should == 8
      end
    end
  end

  describe "#in_lspace" do
    before do
      @klass = Class.new do
        def initialize(task=nil, &block)
          @block = block || task
        end
        in_lspace :initialize

        def call
          @block.call
        end

        private

        def private_test(&block)
          block
        end

        protected

        def protected_test(&block)
          block
        end

        in_lspace :private_test, :protected_test
      end
    end

    it "should automatically preserve LSpace for blocks that are passed in" do
      @task = LSpace.update :user_id => 6 do
                @klass.new{ LSpace[:user_id] }
              end

      @task.call.should == 6
    end

    it "should automatically preserve LSpace for procs that are passed in" do
      @task = LSpace.update :user_id => 6 do
                @klass.new proc{ LSpace[:user_id] }
              end

      @task.call.should == 6
    end

    it "should preserve visibility of methods" do
      @klass.private_method_defined?(:private_test).should == true
      @klass.protected_method_defined?(:protected_test).should == true
    end

    it "should be idempotent" do
      @klass.in_lspace :initialize

      LSpace.update :user_id => 9 do
        @task = @klass.new{ LSpace[:user_id] }
      end
      @task.call.should == 9
    end
  end
end

describe Proc do
  describe "#in_lspace" do
    it "should create a wrapper which preserves the LSpace" do
      p = LSpace.update(:job_id => 19) do
           lambda{ LSpace[:job_id] }.in_lspace
          end

      p.call.should == 19
    end
  end
end
