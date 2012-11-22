require File.expand_path('../lspace/core_ext', __FILE__)

module LSpace

  def self.[](key)
    self.contexts.each do |c|
      return c[key] if c.has_key?(key)
    end
    nil
  end

  def self.[]=(key, value)
    context[key] = value
  end

  def self.get_all(key)
    self.contexts.reverse.map{ |c| c[key] }.compact
  end


  def self.new(context={}, &block)
    context[:outer_lspace] = self.context
    if block_given?
      enter(context, &block)
    else
      context
    end
  end

  def self.enter(context, &block)
    previous_context = self.context
    self.context = context

    get_all(:around_filter).inject(block) do |block, filter|
      lambda{ filter.call(&block) }
    end.call
  ensure
    self.context = previous_context
  end

  def self.preserve(&original)
    context = self.context

    proc do |*args, &block|
      LSpace.enter(context) do
        original.call(*args, &block)
      end
    end
  end

  def self.around_filter(&new_filter)
    if old_filter = context[:around_filter]
      context[:around_filter] = lambda{ |&block| old_filter.call{ new_filter.call(&block) } }
    else
      context[:around_filter] = new_filter
    end
  end

  def self.contexts
    c = self.context
    a = []
    while c
      a << c
      c = c[:outer_lspace]
    end
    a
  end

  def self.context
    Thread.current[:lspace] ||= {}
  end

  def self.context=(context)
    Thread.current[:lspace] = context
  end
end

def LSpace(*args, &block)
  LSpace.preserve(*args, &block)
end
