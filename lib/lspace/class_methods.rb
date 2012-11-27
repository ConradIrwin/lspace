class LSpace

  # Create a new clean LSpace.
  #
  # This LSpace does not inherit any LSpace variables in the currently active LSpace.
  #
  # @example
  #   RSpec.configure do |c|
  #     c.around(:each) do |example|
  #       LSpace.clean do
  #         example.run
  #       end
  #     end
  #   end
  #
  # @param [Proc] block  The logical block that will be run in the clean LSpace
  # @see LSpace.enter
  def self.clean(&block)
    enter new({}, nil), &block
  end

  # Create a new LSpace with the given keys set to the given values.
  #
  # The LSpace will inherit any unspecified keys from the currently active LSpace.
  #
  # @example
  #   LSpace.update :user_id => 6 do
  #     LSpace.update :job_id => 7 do
  #       LSpace[:user_id] == 6
  #       LSpace[:job_id] == 7
  #     end
  #   end
  #
  # @param [Hash] hash  The keys to update
  # @param [Proc] block  The logical block to run with the updated LSpace
  # @see LSpace.enter
  def self.update(hash={}, &block)
    enter new(hash, current), &block
  end

  # Enter an LSpace for the logical duration of the block.
  #
  # The LSpace will be active at least for the duration of the block's callstack,
  # but if the block creates any closures (using LSpace.preserve directly, or in
  # library form) then the logical duration will also encompass code run in those
  # closures.
  #
  # Entering an LSpace will also cause any around_filters defined on it and its parents to
  # be run.
  #
  # @example
  #   class Job
  #     def initialize
  #       @lspace = LSpace.new(:job_id => self.id)
  #       LSpace.enter(@lspace){ setup_lspace }
  #     end
  #
  #     def run!
  #       LSpace.enter(@lspace) { run }
  #     end
  #   end
  #
  # @param [LSpace] lspace  The LSpace to enter
  # @param [Proc] block  The logical block to run with the given LSpace
  def self.enter(lspace, &block)
    previous = current
    self.current = lspace

    filters = lspace.hierarchy.take_while{ |lspace| lspace != previous }.flat_map(&:around_filters)

    filters.inject(block) do |blk, filter|
      lambda{ filter.call(&blk) }
    end.call
  ensure
    self.current = previous
  end

  # Create a closure that will re-enter the current LSpace when the block is called.
  #
  # @example
  #   class TaskQueue
  #     def queue(&block)
  #       @queue << LSpace.preserve(&block)
  #     end
  #   end
  #
  # @see Proc#in_lspace
  # @param [Proc] block  The logical block to wrap
  def self.preserve(&block)
    current.wrap(&block)
  end

  # Get the value for the key in the current LSpace or its parents
  #
  # @see LSpace#[]
  def self.[](key)
    current[key]
  end

  # Set the value for the key in the current LSpace
  #
  # @see LSpace#[]=
  def self.[]=(key, value)
    current[key] = value
  end

  # Add an around filter to the current LSpace
  #
  # @see LSpace#around_filter
  def self.around_filter(&filter)
    current.around_filter(&filter)
  end

  # Get the current LSpace
  #
  # @return [LSpace]
  def self.current
    Thread.current[:lspace] ||= LSpace.new({}, nil)
  end

  private

  # Update the current LSpace
  #
  # @see LSpace.enter
  def self.current=(lspace)
    Thread.current[:lspace] = lspace
  end
end
