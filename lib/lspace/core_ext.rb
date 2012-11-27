class Module
  # Create getter methods for LSpace
  #
  # Assumes that your LSpace keys are Symbols.
  #
  # @example
  #   class Job
  #     lspace_reader :user_id
  #
  #     def user
  #       User.find(user_id)
  #     end
  #   end
  #
  #   LSpace[:user_id] = 6
  #   Job.new.user == #<User:6>
  #
  # @param [Symbol] attrs The accessors to create
  def lspace_reader(*attrs)
    attrs.each do |attr|
      define_method(attr) do
        LSpace[attr]
      end
    end
  end

  # Preserve lspace of all blocks passed to this function.
  #
  # This wraps both the &block parameter, and also any Procs
  # that are passed into the function directly.
  #
  # If you need more complicated logic (e.g. wrapping Procs
  # that are passed to a function in a dictionary) you're
  # on your own.
  #
  # @example
  #   class << Thread
  #     in_lspace :new, :start, :fork
  #   end
  #
  #   LSpace.new :user_id => 2 do
  #     Thread.new{ LSpace[:user_id] == 2 }
  #   end
  #
  # @param [Symbol] methods  The methods to wrap
  def in_lspace(*methods)
    methods.each do |method|
      method_without_lspace = "#{method}_without_lspace"

      # Idempotence: do nothing if the _without_lspace method already exists.
      # method_defined? matches public and protected methods; private methods need a separate check.
      next if method_defined?(method_without_lspace) || private_method_defined?(method_without_lspace)

      alias_method method_without_lspace, method

      define_method(method) do |*args, &block|
        args.map!{ |a| Proc === a ? a.in_lspace : a }
        block = block.in_lspace if block
        __send__(method_without_lspace, *args, &block)
      end

      private method if private_method_defined?(method_without_lspace)
      protected method if protected_method_defined?(method_without_lspace)
    end
  end
end

class Proc
  # Preserve LSpace when this Proc is run. Returns a new Proc, a closure that
  # re-enters the current LSpace when it is called.
  #
  # @example
  #   todo = LSpace.new :user_id => 2 do
  #            proc{ LSpace[:user_id] }.in_lspace
  #          end
  #   todo.call == 2
  # @see LSpace.preserve
  # @return [Proc] A version of self that re-enters LSpace before running
  def in_lspace
    LSpace.preserve(&self)
  end
end
