require "decorators"

module Spec
  module Matchers
    def have_stdout(regex)
      regex = /^#{Regexp.escape(regex)}$/ if regex.is_a?(String)

      simple_matcher("have_stdout") do |given, matcher|
        $stdout = StringIO.new
        given.call
        $stdout.rewind
        captured = $stdout.read

        matcher.failure_message = "Expected #{regex} but got #{captured}"

        $stdout = STDOUT
        captured =~ regex
      end
    end
  end
end

module Kernel
  def silence_stdout
    $stdout = StringIO.new
    yield
    $stdout = STDOUT
  end
end

describe "a class with simple method decorators" do
  class MyDecorator
    def initialize(klass, meth)
      puts "Initializing MyDecorator for #{klass}"
      @meth = meth
    end

    def call(this)
      puts "Inside MyDecorator#call"
    end
  end

  class MyDecorator2
    def initialize(klass, meth)
      puts "Initializing MyDecorator2 for #{klass}"
      @meth = meth
    end

    def call(this)
      puts "Inside MyDecorator#call"
    end
  end

  it "makes a new instance of the decorator when a decorated method is added" do
    lambda do
      class Simple1
        extend MethodDecorators

        decorate MyDecorator
        def a_function
          puts "Inside a_function"
        end
      end
    end.should have_stdout "Initializing MyDecorator for Simple1\n"
  end

  it "initializes multiple decorators when a decorated method is added" do
    lambda do
      class Simple2
        extend MethodDecorators

        decorate MyDecorator
        decorate MyDecorator2
        def a_function
          puts "Inside a_function"
        end
      end
    end.should have_stdout "Initializing MyDecorator for Simple2\n" \
                           "Initializing MyDecorator2 for Simple2\n"
  end

  it "calls the decorator instead of the method" do
    silence_stdout do
      class Simple3
        extend MethodDecorators

        decorate MyDecorator
        def a_function
          puts "Inside a_function"
        end
      end
    end

    lambda do
      Simple3.new.a_function
    end.should have_stdout "Inside MyDecorator#call"
  end

  it "can wrap a function" do
    lambda do
      class MyDecorator3 < Decorator
        def initialize(klass, meth)
          @meth = meth
        end

        def call(this)
          puts "Before MyDecorator#call"
          @meth.bind(this).call
          puts "After MyDecorator#call"
        end
      end

      class Simple4
        extend MethodDecorators

        decorate MyDecorator3
        def a_function
          puts "Inside a_function"
        end
      end

      Simple4.new.a_function
    end.should have_stdout "Before MyDecorator#call\nInside a_function\nAfter MyDecorator#call"
  end

  it "passes on any arguments to the method to decorator#call" do
    class MyDecorator4 < Decorator
      def call(this, *args)
        puts args.inspect
        puts "BLOCK" if block_given?
      end
    end

    lambda do
      class Simple5
        extend MethodDecorators

        decorate MyDecorator4
        def a_function
          puts "Inside a_function"
        end
      end

      Simple5.new.a_function("omg", "omg") {}
    end.should have_stdout %{["omg", "omg"]\nBLOCK}
  end

  it "supports a simpler syntax" do
    class MyDecorator5 < Decorator
      def call(this, *args)
        puts args.inspect
        puts "BLOCK" if block_given?
      end
    end

    lambda do
      class Simple5
        extend MethodDecorators

        MyDecorator5()
        def a_function
          puts "Inside a_function"
        end
      end

      Simple5.new.a_function("omg", "omg") {}
    end.should have_stdout %{["omg", "omg"]\nBLOCK}
  end

  it "supports giving the decorator a name" do
    module Omg
      class MyDecorator6 < Decorator
        decorator_name :surround_it

        def call(this, *args)
          puts args.inspect
          puts "BLOCK" if block_given?
        end
      end
    end

    lambda do
      class Simple6
        extend MethodDecorators

        surround_it
        def a_function
          puts "Inside a_function"
        end
      end
    end
  end

  it "supports decorators with arguments" do
    class ExtraParams
      def initialize(klass, method, *args)
        @method, @args = method, args
      end

      def call(this, *args)
        @method.bind(this).call(*(args + @args))
      end
    end

    class WithExtraParams
      extend MethodDecorators

      ExtraParams(:c, :d)
      def function(a, b, c, d)
        [a, b, c, d]
      end
    end

    WithExtraParams.new.function(:a, :b).should == [:a, :b, :c, :d]
  end
end