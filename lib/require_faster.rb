# $stderr.puts "loading #{__FILE__}"
require 'thread'

module RequireFaster
  def self.activate!
    PathWatcher.activate!
    self.activate_Kernel!
    self
  end

  LOADED = { }
  LOADED_MUTEX = Mutex.new

  def self.activate_Kernel!
    Kernel.module_eval do
      def require_faster name
        path = ::RequireFaster::Cache.instance.find_in_search_path(name)
        unless path
          raise LoadError, "no such file to load -- #{name}"
        end
        do_load = 
        LOADED_MUTEX.synchronize do
          unless LOADED[path]
            LOADED[path] = name
          end
        end
        do_load and require_without_require_faster(path) # => true
      end
      alias :require_without_require_faster :require
      alias :require :require_faster
    end
    self
  end
end
require 'require_faster/cache'
RequireFaster.activate! # if (ENV['RUBYOPTS'] || '') =~ /-rrequire_faster/
$stderr.puts "loading #{__FILE__}: DONE"

