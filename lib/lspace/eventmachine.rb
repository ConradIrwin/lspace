require 'eventmachine'
module EventMachine
  module Deferrable
    in_lspace :callback, :errback
  end

  class << Connection
    alias_method :allocate_without_lspace, :allocate

    def allocate
      allocate_without_lspace.instance_eval do
        extend EventMachine::LSpacePreserver
        @lspace_context = LSpace.new
        lspace_setup
        self
      end
    end

  end

  class Connection
    def lspace_setup; end
  end

  module LSpacePreserver
    [:initialize, :post_init, :connection_completed, :receive_data, :ssl_verify_peer, :ssl_handshake_completed].each do |method|
      define_method(method) { |*a, &b| LSpace.enter(@lspace_context) { super(*a, &b) } }
    end

    [:unbind].each do |method|
      define_method(method) { LSpace.enter(@lspace_context) { super() } }
    end
  end
end

class << EventMachine
  in_lspace :add_timer, :next_tick, :error_handler, :defer, :run, :run_block, :schedule, :fork_reactor
  in_lspace :add_shutdown_hook if method_defined?(:add_shutdown_hook)
end
