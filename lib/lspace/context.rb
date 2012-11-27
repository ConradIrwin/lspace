class LSpace
  class Context
    def initialize(data = {})
      @data = data
    end
    attr_accessor :parent
    attr_reader :data, :around_filter

    def enter(&block)
      new_frames = active.take_while{ |space| space != @parent }
      filters = new_frames.map{ |space| space.around_filter }.compact

      filters.inject(block) do |block, filter|
        lambda{ filter.call(&block) }
      end.call
    end

    def [](key)
      active.each do |c|
        return c.data[key] if c.data.has_key?(key)
      end
      nil
    end

    def has_key?(key)
      active.any? do |c|
        c.has_key?(key)
      end
    end

    def []=(key, value)
      @data[key] = value
    end

    def add_around_filter(&new_filter)
      if old_filter = @around_filter
        @around_filter = lambda{ |&block| old_filter.call{ new_filter.call(&block) } }
      else
        @around_filter = new_filter
      end
    end

    # All active LSpaces from most-specific to most-generic
    #
    # @return [Array<LSpace::Context>]
    def active
      c = self
      a = []
      while c
        a << c
        c = c.parent
      end
      a
    end
  end
end
