require File.expand_path('../lspace/core_ext', __FILE__)
require File.expand_path('../lspace/class_methods', __FILE__)

# An LSpace is an implicit namespace for storing state that is secondary to your
# application's purpose, but still necessary.
#
# In many ways they are the successor to the Thread-local namespace, but they are designed
# to be active during a logical segment of code, no matter how you slice that code amongst
# different Threads or Fibers.
#
# The API for LSpace encourages creating a new sub-LSpace whenever you want to mutate the
# value of an LSpace-variable. This ensures that local changes take effect only for code
# that is logically contained within a block, avoiding many of the problems of mutable
# global state.
#
# @example
#   require 'lspace/thread'
#   LSpace.with(:job_id => 1) do
#     Thread.new do
#       puts "processing #{LSpace[:job_id]}"
#     end.join
#   end
#
class LSpace

  attr_accessor :hash, :parent, :around_filters

  # Create a new LSpace.
  #
  # By default the new LSpace will exactly mirror the currently active LSpace,
  # though any variables you pass in will take precedence over those defined in the
  # parent.
  #
  # @param [Hash] hash  New values for LSpace variables in this LSpace
  # @param [LSpace] parent  The parent LSpace that lookup should default to.
  # @param [Proc] block  Will be called in the new lspace if present.
  def initialize(hash={}, parent=LSpace.current, &block)
    @hash = hash
    @parent = parent
    @around_filters = []
    enter(&block) if block_given?
  end

  # Get the most specific value for the key.
  #
  # If the key is not present in the hash of this LSpace, lookup proceeds up the chain
  # of parent LSpaces. If the key is not found anywhere, nil is returned.
  #
  # @example
  #   LSpace.with :user_id => 5 do
  #     LSpace.with :user_id => 6 do
  #       LSpace[:user_id] == 6
  #     end
  #   end
  # @param [Object] key
  # @return [Object]
  def [](key)
    hierarchy.each do |lspace|
      return lspace.hash[key] if lspace.hash.has_key?(key)
    end

    nil
  end

  # Update the LSpace-variable with the given name.
  #
  # Bear in mind that any code using this LSpace will see this change, and consider
  # using {LSpace.with} or {LSpace.fork} instead to localize your changes.
  #
  # This method is mostly useful for setting up a new LSpace before any code is
  # using it, and has no effect on parent LSpaces.
  #
  # @example
  #   lspace = LSpace.new
  #   lspace[:user_id] = 6
  #   LSpace.enter(lspace) do
  #     LSpace[:user_id] == 6
  #   end
  # @param [Object] key
  # @param [Object] value
  def []=(key, value)
    hash[key] = value
  end

  # Add an around_filter to this LSpace.
  #
  # Around filters are blocks that take a block-parameter. They are called whenever
  # the LSpace is re-entered, so they are suitable for implementing integrations between
  # LSpace and libraries that rely on Thread-local state (like Log4r) or for adding
  # fallback exception handlers to your logical segment of code (to prevent exceptions
  # from killing your Thread-pool or event loop).
  #
  # @example
  #   lspace = LSpace.new
  #   lspace.around_filter do |&block|
  #     begin
  #       block.call
  #     rescue => e
  #       puts "Job #{LSpace[:job_id]} failed with: #{e}"
  #     end
  #   end
  #
  #   LSpace.enter(lspace) do
  #     Thread.new{ raise "foo" }.join
  #   end
  #
  def around_filter(&filter)
    around_filters.unshift filter
    self
  end

  # Enter this LSpace for the duration of the block
  #
  # @see LSpace.enter
  # @param [Proc] block  The block to run
  def enter(&block)
    LSpace.enter(self, &block)
  end

  # Wraps a block/proc such that it runs in this LSpace when it is called.
  #
  # @see Proc#in_lspace
  # @see LSpace.preserve
  def wrap(&original)
    # Store self so that it works if the block is instance_eval'd
    shelf = self

    proc do |*args, &block|
      shelf.enter do
        original.call(*args, &block)
      end
    end
  end

  # Get the list of Lspaces up to the root, most specific first
  #
  # @return [Array<LSpace>]
  def hierarchy
    @hierarchy ||= if parent
                     [self] + parent.hierarchy
                   else
                     [self]
                   end
  end
end
