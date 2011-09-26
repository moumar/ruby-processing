module Processing
  # This module will get automatically mixed in to any inner class of
  # a Processing::App, in order to mimic Java's inner classes, which have
  # unfettered access to the methods defined in the surrounding class.
  module Proxy
    include Math

    # Generate the list of method names that we'd like to proxy for inner classes.
    # Nothing camelCased, nothing __internal__, just the Processing API.
    def desired_method_names
      bad_method = /__/    # Internal JRuby methods.
      unwanted = PApplet.superclass.instance_methods + Object.instance_methods
      unwanted -= ['width', 'height', 'cursor', 'create_image', 'background', 'size', 'resize']
      methods = Processing::App.public_instance_methods
      methods.reject {|m| unwanted.include?(m) || bad_method.match(m) }
    end


    # Proxy methods through to the sketch.
    def proxy_methods
      code = desired_method_names.inject('') do |code, method|
        code << <<-EOS
          def #{method}(*args, &block)                # def rect(*args, &block)
            if block_given?                           #   if block_given?
              $app.send :'#{method}', *args, &block   #     $app.send(:rect, *args, &block)
            else                                      #   else
              $app.#{method} *args                    #     $app.rect *args
            end                                       #   end
          end                                         # end
        EOS
      end
      module_eval(code, "Processing::Proxy", 1)
    end


    # Proxy the sketch's constants on to the inner classes.
    def proxy_constants
      Processing::App.constants.each do |name|
        Processing::Proxy.const_set(name, Processing::App.const_get(name))
      end
    end


    # Don't do all of the work unless we have an inner class that needs it.
    def included(inner_class)
      return if @already_defined
      proxy_methods
      proxy_constants
      @already_defined = true
    end

  end # Processing::Proxy
end
