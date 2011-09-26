module Processing
  module LibraryLoader
    # Detect if a library has been loaded (for conditional loading)
    @@loaded_libraries = Hash.new(false)
    def library_loaded?(folder)
      @@loaded_libraries[folder.to_sym]
    end
    def library_loaded?(folder); self.class.library_loaded?(folder); end


    # Load a list of Ruby or Java libraries (in that order)
    # Usage: load_libraries :opengl, :boids
    #
    # If a library is put into a 'library' folder next to the sketch it will
    # be used instead of the library that ships with Ruby-Processing.
    def load_libraries(*args)
      args.each do |lib|
        loaded = load_ruby_library(lib) || load_java_library(lib)
        raise LoadError.new "no such file to load -- #{lib}" if !loaded
      end
    end
    def load_library(*args); load_libraries(*args); end


    # For pure ruby libraries.
    # The library should have an initialization ruby file
    # of the same name as the library folder.
    def load_ruby_library(dir)
      dir = dir.to_sym
      return true if @@loaded_libraries[dir]
      if Processing.online?
        begin
          return @@loaded_libraries[dir] = (require "library/#{dir}/#{dir}")
        rescue LoadError => e
          return false
        end
      end
      local_path = "#{SKETCH_ROOT}/library/#{dir}"
      gem_path = "#{RP5_ROOT}/library/#{dir}"
      path = File.exists?(local_path) ? local_path : gem_path
      return false unless (File.exists?("#{path}/#{dir}.rb"))
      return @@loaded_libraries[dir] = (require "#{path}/#{dir}")
    end


    # For pure java libraries, such as the ones that are available
    # on this page: http://processing.org/reference/libraries/index.html
    #
    # P.S. -- Loading libraries which include native code needs to
    # hack the Java ClassLoader, so that you don't have to
    # futz with your PATH. But it's probably bad juju.
    def load_java_library(library_name)
      library_name = library_name.to_sym
      return true if @@loaded_libraries[library_name]
      return @@loaded_libraries[library_name] = !!(JRUBY_APPLET.get_parameter("archive").match(%r(#{library_name}))) if Processing.online?
      local_path = "#{SKETCH_ROOT}/library/#{library_name}"
      gem_path = "#{RP5_ROOT}/library/#{library_name}"
      path = File.exists?(local_path) ? local_path : gem_path
      jars = Dir["#{path}/**/*.jar"]
      sketchbook_libraries_path = sketchbook_path + "/libraries"
      if File.exists?(sketchbook_libraries_path)
        jars.concat(Dir["#{sketchbook_libraries_path}/#{library_name}/library/*.jar"])
      end
      return false if jars.empty?
      jars.each {|jar| require jar }

      library_paths = [path, "#{path}/library"]
      library_paths.concat(platform_specific_library_paths.collect { |d| "#{path}/library/#{d}" } )
      library_paths.concat(platform_specific_library_paths.collect { |d| "#{sketchbook_libraries_path}/#{library_name}/library/#{d}" } )
      #p library_paths
      library_paths = library_paths.select do |path|
        test(?d, path) && !Dir.glob(File.join(path, "*.{so,dll,jnilib}")).empty?
      end

      #p library_paths
      library_paths << java.lang.System.getProperty("java.library.path")
      new_library_path = library_paths.join(java.io.File.pathSeparator)

      java.lang.System.setProperty("java.library.path", new_library_path)

      field = java.lang.Class.for_name("java.lang.ClassLoader").get_declared_field("sys_paths")
      if field
        field.accessible = true
        field.set(java.lang.Class.for_name("java.lang.System").get_class_loader, nil)
      end
      return @@loaded_libraries[library_name] = true
    end

    def sketchbook_path
      preferences_paths = []
      sketchbook_paths = []
      ["Application Data/Processing", "AppData/Roaming/Processing", 
       "Library/Processing", "Documents/Processing", 
       ".processing", "sketchbook"].each do |prefix|
        path = "#{ENV["HOME"]}/#{prefix}"
        pref_path = path+"/preferences.txt"
        if test(?f, pref_path)
          preferences_paths << pref_path
        end
        if test(?d, path)
          sketchbook_paths << path
        end
      end
      if !preferences_paths.empty?
        matched_lines = File.readlines(preferences_paths.first).grep(/^sketchbook\.path=(.+)/) { $1 }
        return matched_lines.first
      else
        sketchbook_paths.first
      end
    end

    def platform_specific_library_paths
      bits = "32"
      if java.lang.System.getProperty("sun.arch.data.model") == "64" || 
         java.lang.System.getProperty("java.vm.name").index("64")
        bits = "64"
      end

      match_string, platform = {"Mac" => "macosx", "Linux" => "linux", "Windows" => "windows" }.detect do |string, platform_|
        java.lang.System.getProperty("os.name").index(string)
      end
      platform ||= "other"
      [ platform, platform+bits ]
    end

  end
end
