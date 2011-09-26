# This class is a thin wrapper around Processing's PApplet.
# Most of the code here is for interfacing with Swing,
# web applets, going fullscreen and so on.

require 'java'
require 'ruby-processing/library_loader'
require 'ruby-processing/helper_methods'
require 'ruby-processing/proxy'

module Processing

  # Conditionally load core.jar
  require "#{RP5_ROOT}/lib/core/core.jar" unless Processing.online? || Processing.embedded?
  import "processing.core"

  # This is the main Ruby-Processing class, and is what you'll
  # inherit from when you create a sketch. This class can call
  # all of the methods available in Processing, and has two
  # mandatory methods, 'setup' and 'draw', both of which you
  # should define in your sketch. 'setup' will be called one
  # time when the sketch is first loaded, and 'draw' will be
  # called constantly, for every frame.
  class App < PApplet
    class << self
      include LibraryLoader
      include Proxy
    end
    include Math
    include HelperMethods

    # Include some processing classes that we'd like to use:
    %w(PShape PImage PGraphics PFont PVector).each do |klass|
      import "processing.core.#{klass}"
    end

    # When certain special methods get added to the sketch, we need to let
    # Processing call them by their expected Java names.
    def self.method_added(method_name) #:nodoc:
      # Watch the definition of these methods, to make sure
      # that Processing is able to call them during events.
      methods_to_alias = {
        :mouse_pressed  => :mousePressed,
        :mouse_dragged  => :mouseDragged,
        :mouse_clicked  => :mouseClicked,
        :mouse_moved    => :mouseMoved,
        :mouse_released => :mouseReleased,
        :key_pressed    => :keyPressed,
        :key_released   => :keyReleased,
        :key_typed      => :keyTyped
      }
      if methods_to_alias.keys.include?(method_name)
        alias_method methods_to_alias[method_name], method_name
      end
    end


    # Class methods that we should make available in the instance.
    [:map, :pow, :norm, :lerp, :second, :minute, :hour, :day, :month, :year,
     :sq, :constrain, :dist, :blend_color, :degrees, :radians, :mag, :println,
     :hex, :min, :max].each do |meth|
      method = <<-EOS
        def #{meth}(*args)
          self.class.#{meth}(*args)
        end
      EOS
      eval method
    end

    # Handy getters and setters on the class go here:
    def self.sketch_class;  @sketch_class;        end

    # Keep track of what inherits from the Processing::App, because we're going
    # to want to instantiate one.
    def self.inherited(subclass)
      super(subclass)
      @sketch_class = subclass
    end

    def self.has_slider(*args) #:nodoc:
      raise "has_slider has been replaced with a nicer control_panel library. Check it out."
    end


    # When you make a new sketch, you pass in (optionally),
    # a width, height, x, y, title, and whether or not you want to
    # run in full-screen.
    #
    # This is a little different than Processing where height
    # and width are declared inside the setup method instead.
    def initialize(options={})
      super()

      java.lang.Thread.default_uncaught_exception_handler = proc do |thread, exception|
        #p java_class.declared_field("defaultSize").value(Java.ruby_to_java(self))
        exception.print_stack_trace
        close
      end

      proxy_java_fields
      args = []
      if options[:x] && options[:y]
        args << "--location=#{options[:x]},#{options[:y]}"
      end
      @full_screen = false
      if options[:full_screen]
        @full_screen = true
        args << "--present"
      end
      title = options[:title] || File.basename(SKETCH_PATH).sub(/(\.rb|\.pde)$/, '').titleize
      args << title
      PApplet.run_sketch(args, self)
    end

    def hint(*args)
      begin
        super(*args)
      rescue Exception => e
        raise e.cause
      end
    end

    def size(*args)
      begin
        super(*args)
      rescue Exception => e
        raise e.cause
      end
    end


    # Provide a loggable string to represent this sketch.
    def inspect
      "#<Processing::App:#{self.class}:#{@title}>"
    end

    # Cleanly close and shutter a running sketch.
    def close
      if Processing.online?
        JRUBY_APPLET.remove(self)
        self.dispose
      else
        control_panel.remove if respond_to?(:control_panel)
        self.dispose
        self.frame.dispose
      end
    end

    private

  end # Processing::App
end # Processing
