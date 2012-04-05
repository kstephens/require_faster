require 'require_faster'
require 'thread'

module RequireFaster
  module PathWatcher
    def self.activate!
      $:.extend(self)
      self
    end
    class_eval([
                 :<<,
                 :unshift,
                 :shift,
                 :push,
                 :pop,
                 :[]=,
                 :delete,
                 :delete_if,
                 :replace,
                 :insert,
                 :map!,
               ].map do | name |
                    <<"END"
def #{name} *args, &blk
  $stderr.puts "  # RF: $: #{name} \#{args.inspect}" if DEBUG >= 1
  Cache.search_path_changed!
  super(*args, &blk)
end
END
    end * "\n")
  end

  class Cache
    class << self
      MUTEX_0 = Mutex.new
      attr_accessor :search_path_version
      def search_path_changed!
        MUTEX_0.synchronize do
          self.search_path_version ||= 0
          self.search_path_version += 1
          self.invalidate_search_path_cache!
        end
        self
      end
    end

    def self.instance
      Thread.current[:'RequireFaster::Cache.instance'] ||=
        THREADS_MUTEX.synchronize do
          x = self.new
          THREADS[Thread.current] = x
          x
        end
    end
    THREADS = { }
    THREADS_MUTEX = Mutex.new

    MUTEX_1 = Mutex.new
    def self.invalidate_search_path_cache!
      THREADS_MUTEX.synchronize do
        dead_threads = [ ]
        THREADS.each do | thread, cache |
          if thread.alive?
            dead_threads << thread
          else
            cache.search_path_changed!
          end
        end
        dead_threads.each { | t | THREADS.delete(t) }
      end
      self
    end

    attr_accessor :search_path_version

    def initialize
      @cache_find_in_search_path = { }
      @cache_readable_file_ = { }
      @cache_abs_path = { }
    end

    def find_in_search_path name
      (
        @cache_find_in_search_path[name] ||=
        [
          _find_in_search_path(name)
        ]
        ).first
    end

    def _find_in_search_path name
      $stderr.puts "  # RF: __find_in_search_path #{name.inspect}" if DEBUG >= 2
      case name
      when %r{\A/}
        fullpath = name
      else
        fullpath = nil
        @search_path ||= $:.map{|dir| dir.dup.freeze}.freeze
        @search_path.each do | dir |
          dir = abs_path(dir)
          SUFFIXES.each do | suf |
            if readable_file?(try = "#{dir}/#{name}#{suf}")
              fullpath = try
              break
            end
            $stderr.puts "  # RF: try #{try.inspect}" if DEBUG >= 3
          end
          break if fullpath
        end
      end
      fullpath
    end
    SUFFIXES = [ '', '.rb', '.so' ].map!{|x| x.freeze}.freeze

    def readable_file? path
      (
        @cache_readable_file_[path.freeze] ||=
        [
          (
            s = ::File.stat(path) rescue nil
            x = s && s.file? && s.readable?
            $stderr.puts "  # RF: readable_file? #{path.inspect} => #{x.inspect}" if DEBUG >= 2
            x
            )
        ]
        ).first
    end

    def abs_path path
      @cache_abs_path[path.freeze] ||=
        (
        x = ::File.expand_path(path)
        $stderr.puts "  # RF: abs_path #{path.inspect} => #{x.inspect}" if DEBUG >= 2
        x
        )
    end

    def search_path_changed!
      flush_search_path!
    end

    def flush!
      flush_search_path!
    end

    def flush_search_path!
      @find_in_search_path_cache.clear
      @search_path = nil
      self
    end
  end
end
