require File.expand_path('../lspace/core_ext', __FILE__)
require File.expand_path('../lspace/context', __FILE__)

class LSpace
  class << self
    # Get the most specific value for the key.
    #
    # If nested LSpaces are active, returns the value set in the innermost scope.
    # If this key is not present in any of the nested LSpaces, nil is returned.
    #
    # @example
    #   LSpace.new :user_id => 5 do
    #     LSpace.new :user_id => 6 do
    #       LSpace[:user_id] == 6
    #     end
    #   end
    # @param [Object] key
    # @return [Object]
    def [](key)
      current[key]
    end

    # Sets the value for the key in the currently active LSpace.
    #
    # This does not have any effect on outer LSpaces.
    #
    # If your LSpace is shared between threads, you should think very hard before
    # changing a value, it's often better to create a new LSpace if you want to
    # override a value temporarily.
    #
    # @example
    #   LSpace.new :user_id => 5 do
    #     LSpace.new do
    #       LSpace[:user_id] = 6
    #       LSpace[:user_id] == 6
    #     end
    #     LSpace[:user_id] == 5
    #   end
    #
    # @param [Object] key
    # @param [Object] value
    # @return [Object] value
    def []=(key, value)
      current[key] = value
    end

    # Create a new LSpace.
    #
    # If a block is passed, then the block is called in the new LSpace,
    # otherwise you can manually pass the LSpace to {LSpace.enter} later.
    #
    # The returned LSpace will inherit from the currently active LSpace:
    #
    # @example
    #   LSpace.new :job_id => 7 do
    #     LSpace[:job_id] == 7
    #   end
    #
    # @example
    #   class Job
    #     def initialize
    #       @lspace = LSpace.new
    #     end
    #
    #     def run!
    #       LSpace.enter(@lspace){ run }
    #     end
    #   end
    #
    # @param [Hash] data  Values to set in the new LSpace
    # @param [Proc] block  The block to run
    # @return [LSpace::Context] The new LSpace (unless a block is given)
    # @return [Object]  The return value of the block (if a block is given)
    def new(data={}, &block)
      new = LSpace::Context.new(data)
      new.parent = current
      if block_given?
        enter(new, &block)
      else
        new
      end
    end

    # Enter an LSpace
    #
    # This sets a new LSpace to be current for the duration of the block,
    # it also runs any around filters for the new space. (Around filters that
    # were present in the previous space are not run again).
    #
    # @example
    #   class Job
    #     def initialize
    #       @lspace = LSpace.new
    #     end
    #
    #     def run!
    #       LSpace.enter(@lspace){ run }
    #     end
    #   end
    #
    # @param [LSpace::Context] new  The LSpace to enter
    # @param [Proc] block  The block to run
    def enter(new, &block)
      previous = current
      self.current = new

      current.enter(&block)
    ensure
      self.current = previous
    end

    # Preserve the current LSpace when this block is called
    #
    # @example
    #   LSpace.new :user_id => 1 do
    #     $todo = LSpace.preserve do |args|
    #               LSpace[:user_id]
    #             end
    #   end
    #   $todo.call == 1
    #
    # @see [Proc#in_lspace]
    # @param [Proc] original  The block to wrap
    # @return [Proc] A modified block that will be executed in the current LSpace.
    def preserve(&original)
      current = self.current

      proc do |*args, &block|
        LSpace.enter(current) do
          original.call(*args, &block)
        end
      end
    end

    # Add an around filter for the current LSpace
    #
    # The filter will be called every time this LSpace is entered on a new call stack, which
    # makes it suitable for maintaining state in libraries that are not LSpace aware (like
    # log4r) or implementing unified fallback error handling.
    #
    # Bear in mind that when you add an around_filter to the current LSpace it will not be
    # running. For this reason, you should try and set up around filters before using the
    # LSpace properly.
    #
    # @example
    #   class Job
    #     def initialize
    #       LSpace.new do
    #
    #         LSpace.around_filter do |&block|
    #           begin
    #             block.call
    #           rescue => e
    #             puts "Job #{LSpace[:job_id]} failed with: #{e}"
    #           end
    #         end
    #
    #         @lspace = LSpace.current
    #       end
    #     end
    #
    #     def run!
    #       LSpace.enter(@lspace){ run }
    #     end
    #   end
    #
    # @param [Proc] new_filter A Proc that takes a &block argument.
    def around_filter(&new_filter)
      current.add_around_filter(new_filter)
    end

    # Get the currently active LSpace
    #
    # @see LSpace.enter
    # @param [Hash] new  The new LSpace
    def current
      Thread.current[:lspace] ||= Context.new
    end

    private

    # Set the current LSpace
    #
    # @see LSpace.enter
    # @param [LSpace::Context] new  The new LSpace
    def current=(new)
      Thread.current[:lspace] = new
    end
  end
end
