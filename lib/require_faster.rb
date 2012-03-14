# $stderr.puts "loading #{__FILE__}"
require 'thread'

module RequireFaster
  DEBUG = (ENV['RequireFaster_DEBUG'] || 0).to_i

  def self.activate!
    PathWatcher.activate!
    self.activate_Kernel!
    $stderr.puts "  # RF: activate!: DONE." if DEBUG >= 1
    $stderr.puts "  # RF: $: => #{$:.inspect}"
    $stderr.puts "  # RF: $" => #{$".inspect}" #"
    self
  end

  LOADED_PATH = { }
  LOADED_NAME = { }
  LOADED_MUTEX = Mutex.new

  def self.activate_Kernel!
    Kernel.module_eval do
      def require_faster name
        $stderr.puts "  # RF: require_faster #{name.inspect} ..." if DEBUG >= 2
        path = ::RequireFaster::Cache.instance.find_in_search_path(name)
        unless path
          raise LoadError, "no such file to load -- #{name}"
        end
        do_load = false
        LOADED_MUTEX.synchronize do
          unless LOADED_PATH[path] or LOADED_NAME[name]
            LOADED_PATH[path] = name
            LOADED_NAME[name] = path
            # Do not load, if it was required before require_faster was activated.
            do_load = ! ($".include?(name) || $".include?(path))
          end
        end
        if do_load
          $stderr.puts "  # RF: require_faster #{name.inspect}\n  #   path #{path.inspect}" if DEBUG >=1
          $stderr.puts "  #   from #{caller * "\n       "}" if DEBUG >= 2
          require_without_require_faster(path) # => true
          $".push(name)
        else
          false
        end
      end
      alias :require_without_require_faster :require
      alias :require :require_faster
    end
    self
  end
end
require 'require_faster/cache'
RequireFaster.activate! if (ENV['RUBYOPT'] || '') =~ /-rrequire_faster/
# $stderr.puts "loading #{__FILE__}: DONE"

