class Module
  def in_lspace(*methods)
    methods.each do |method|
      method_without_lspace = "#{method}_without_lspace"
      next if method_defined?(method_without_lspace) || private_method_defined?(method_without_lspace)

      alias_method method_without_lspace, method

      define_method(method) do |*args, &block|
        args.map!{ |a| Proc === a ? a.in_lspace : a }
        block = block && block.in_lspace
        __send__(method_without_lspace, *args, &block)
      end

      private method if private_method_defined?(method_without_lspace)
      protected method if protected_method_defined?(method_without_lspace)
    end
  end

  def attr_lspace(*attrs)
    attrs.each do |attr|
      define_method(attr) do
        LSpace[attr]
      end

      define_method("#{attr}=") do |value|
        LSpace[attr] = value
      end
    end
  end
end

class Proc
  def in_lspace
    LSpace(&self)
  end
end
