module MethodDecorators
  def self.extended(klass)
    class << klass
      attr_accessor :decorated_methods
    end
  end
  
  def method_added(name)
    return unless @decorators
    
    decorators = @decorators.dup
    @decorators = nil
    @decorated_methods ||= Hash.new {|h,k| h[k] = []}
    
    class << self; attr_accessor :decorated_methods; end
    
    decorators.each do |klass|
      decorator = klass.new(self, name)
      @decorated_methods[name] << decorator
    end
    
    alias_method "undecorated_#{name}", name
    
    class_eval <<-ruby_eval, __FILE__, __LINE__ + 1
      def #{name}(*args, &blk)
        self.class.decorated_methods[#{name.inspect}].each do |decorator|
          decorator.call(self, *args, &blk)
        end
      end
    ruby_eval
  end
  
  def decorate(klass)
    @decorators ||= []
    @decorators << klass
  end
end

class Decorator
  def self.decorator_name(name)
    @decorator_name = name
  end
  
  def self.inherited(klass)
    name = klass.name.gsub(/^./) {|m| m.downcase}

    return if name =~ /^[^A-Za-z_]/ || name =~ /[^0-9A-Za-z_]/
    
    MethodDecorators.module_eval <<-ruby_eval, __FILE__, __LINE__ + 1
      def #{klass}(*args, &blk)
        decorate(#{klass}, *args, &blk)
      end
    ruby_eval
  end
  
  def initialize(klass, meth)
    @meth = meth
  end
  
  def undecorated(obj, name)
    obj.send("undecorated_#{name}")
  end
end