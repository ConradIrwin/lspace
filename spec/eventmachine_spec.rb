require 'spec_helper'

describe LSpace do
  describe "eventmachine integration" do
    before do
      $foo = :fail
    end

    it "should preserve LSpace in deferrable callbacks" do
      d = Class.new{ include EM::Deferrable }.new
      LSpace.with(:foo => 2) do
        d.callback do
          $foo = LSpace[:foo]
        end
      end
      d.succeed
      $foo.should == 2
    end

    it "should preserve LSpace in deferrable errbacks" do
      d = Class.new{ include EM::Deferrable }.new
      LSpace.with(:foo => 2) do
        d.errback do
          $foo = LSpace[:foo]
        end
      end
      d.fail
      $foo.should == 2
    end

    it "should preserve LSpace in EM::defer operation" do
      EM::run do
        LSpace.with(:foo => 4) do
          EM::defer(lambda{
            $foo = LSpace[:foo]
          }, proc{
            EM::stop
          })
        end
      end
      $foo.should == 4
    end

    it "should preserve LSpace in EM::defer callback" do
      EM::run do
        LSpace.with(:foo => 4) do
          EM::defer(lambda{
            nil
          }, proc{
            $foo = LSpace[:foo]
            EM::stop
          })
        end
      end
      $foo.should == 4
    end

    it "should preserve LSpace in EM.next_tick" do
      EM::run do
        EM::next_tick do
          LSpace.with :foo => 5 do
            EM::next_tick do
              $foo = LSpace[:foo]
              EM::stop
            end
          end
        end

        EM::next_tick do
          LSpace[:foo].should_not == 5
        end
      end
      $foo.should == 5
    end

    it "should preserve LSpace in all connection callbacks" do
      $server = []
      $client = []
      $tick = []
      server = Module.new do
        def setup_lspace
          LSpace[:foo] = :server
        end

        def post_init
          $server << [:post_init, LSpace[:foo], LSpace[:bar]]
        end

        def receive_data(data)
          $server << [:receive_data, LSpace[:foo], LSpace[:bar]]
          send_data(data)
          close_connection_after_writing
        end

        def unbind
          $server << [:unbind, LSpace[:foo], LSpace[:bar]]
        end
      end

      client = Module.new do
        def setup_lspace
          LSpace[:foo] = :client
        end

        def post_init
          $client << [:post_init, LSpace[:foo], LSpace[:bar]]
          send_data("Hi world\n")
        end

        def receive_data(data)
          data.should == "Hi world\n"
          $client << [:receive_data, LSpace[:foo], LSpace[:bar]]
        end

        def unbind
          $client << [:unbind, LSpace[:foo], LSpace[:bar]]
        end
      end

      EM::run do
        LSpace.with(:bar => :baz) do
          EM::start_server '0.0.0.0', 9345, server
          EM::connect '127.0.0.1', 9345, client
          EM::PeriodicTimer.new(0.1) do
            $tick << [:tick, LSpace[:bar]]
            EM::stop
          end
        end
      end

      $client.should == [[:post_init, :client, :baz], [:receive_data, :client, :baz], [:unbind, :client, :baz]]
      $server.should == [[:post_init, :server, :baz], [:receive_data, :server, :baz], [:unbind, :server, :baz]]
      $tick.should == [[:tick, :baz]]
    end

    it "should ensure that around_filters defined outside EM::run are run on each callback inside the reactor" do
      LSpace[:count] = 0
      LSpace.around_filter do |&block|
        LSpace[:count] += 1
        block.call
      end

      LSpace[:count].should == 0
      EM::run do
        LSpace[:count].should == 1
        EM::next_tick do
          LSpace[:count].should == 2
          EM::stop
        end
      end
    end

    it "should not re-enter LSpace if run_in_current_lspace is used" do
      LSpace[:count] = 0
      LSpace.around_filter do |&block|
        LSpace[:count] += 1
        block.call
      end

      LSpace[:count].should == 0
      EM::run_in_current_lspace do
        LSpace[:count].should == 0
        EM::next_tick do
          LSpace[:count].should == 0
          EM::stop
        end
      end
    end

    it "should preserve an argument to unbind if one is given" do
      seen = nil
      client = Module.new do
        define_method(:unbind) do |reason|
          seen = reason
          EM::stop
        end
      end

      EM::run do
        EM::connect 'localhost', 9345, client
      end

      seen.should == Errno::ECONNREFUSED
    end
  end
end
