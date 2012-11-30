require 'celluloid'
require 'lspace'

module Celluloid
  class Call
    alias_method :initialize_without_lspace, :initialize

    def initialize(*args, &block)
      initialize_without_lspace(*args, &block)
      @lspace = LSpace.new
    end
  end

  class SyncCall < Call
    alias_method :dispatch_without_lspace, :dispatch

    def dispatch(*args, &block)
      LSpace.enter(@lspace) { dispatch_without_lspace(*args, &block) }
    end
  end

  class AsyncCall < Call
    alias_method :dispatch_without_lspace, :dispatch

    def dispatch(*args, &block)
      LSpace.enter(@lspace) { dispatch_without_lspace(*args, &block) }
    end
  end
end
