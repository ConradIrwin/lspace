require 'eventmachine'
require 'lspace'

# Optional module to make EventMachine preserve LSpaces in its event callbacks. Not loaded by
# default; you must +require 'lspace/eventmachine'+ to use it.
module EventMachine

  # Most of the low-level EventMachine stuff goes through singleton methods on the
  # EventMachine class.
  #
  # We use in_lspace to preserve the LSpace of any blocks passed to these methods.
  class << self
    in_lspace :add_timer, :next_tick, :error_handler, :defer, :run, :run_block, :schedule, :fork_reactor
    in_lspace :add_shutdown_hook if method_defined?(:add_shutdown_hook) # only some versions of EM
  end

  # Many EM APIs (e.g. em-http-request) are based on deferrables. Preserving lspace for
  # both callbacks and errbacks makes these libraries "just work".
  module Deferrable
    in_lspace :callback, :errback
  end

  class Connection

    class << self
      # As EM uses a custom implementation of new, the only sane way to
      # set up the LSpace in advance is to override allocate.
      alias_method :allocate_without_lspace, :allocate
    end

    # Overridden allocate which sets up a new LSpace.
    #
    # Each connection object is run in its own LSpace, which can be
    # configured by implementing the {Connection#setup_lspace} method.
    def self.allocate
      allocate_without_lspace.instance_eval do
        extend EventMachine::LSpacePreserver
        LSpace.with do
          setup_lspace
          @lspace = LSpace.current
        end
        self
      end
    end

    # Override this method to setup the LSpace in a manner which you require.
    #
    # This method is called before initialize() and before post_init().
    #
    # @example
    #   module EchoServer
    #     def setup_lspace
    #       LSpace.around_filter do |&block|
    #         begin
    #           block.call
    #         rescue => e
    #           self.rescue(e)
    #         end
    #       end
    #     end
    #
    #     def rescue(e)
    #       puts "An exception occurred!: #{e}"
    #     end
    #   end
    def setup_lspace; end
  end

  # A module that's included at the beginning of the method-resolution chain of
  # connections which restores LSpace whenever a callback is fired by the eventloop.
  module LSpacePreserver
    [:initialize, :post_init, :connection_completed, :receive_data, :ssl_verify_peer, :ssl_handshake_completed].each do |method|
      define_method(method) { |*a, &b| LSpace.enter(@lspace) { super(*a, &b) } }
    end

    # EM uses the arity of unbind to decide which arguments to pass it.
    # AFAIK the no-argument version is considerably more popular, so we use that here.
    [:unbind].each do |method|
      define_method(method) { LSpace.enter(@lspace) { super() } }
    end
  end
end
