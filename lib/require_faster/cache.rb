require 'require_faster'
require 'thread'

module RequireFaster
  module PathWatcher
    def self.activate!
      # $:.uniq! # Dangerous?
      $:.extend(self)
      self
    end
    module_eval([
                 :<<,
                 :[]=,
                 :clear,
                 :compact!,
                 :concat,
                 :delete,
                 :delete_if,
                 :drop,
                 :drop_while,
                 :fill,
                 :flatten!,
                 :replace,
                 :keep_if,
                 :collect!,
                 :map!,
                 :reject!,
                 :reverse!,
                 :rotate!,
                 :select!,
                 :shuffle!,
                 :slice!,
                 :sort!,
                 :sort_by!,
                 :uniq!,
                 :unshift,
                 :shift,
                 :push,
                 :pop,
                 :insert,
                 :map!,
               ].select{|name| $:.respond_to?(name)}.
               map do | name |
                    <<"END"
def #{name} *args, &blk
  RequireFaster._log "$LOAD_PATH changed #{name} \#{args.inspect}" if DEBUG[:path_change]
  Cache.search_path_changed!
  result = super(*args, &blk)
  RequireFaster._log "$LOAD_PATH ::\n#{$: * "\n"}" if DEBUG[:path_change_show]
  result
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
      instance.search_path_changed!
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

    attr_accessor :search_path_version, :path_stack

    def initialize
      @cache_find_in_search_path = { }
      @cache_readable_file_ = { }
      @cache_abs_path = { }
      @path_stack = [ ]
    end

    def depth; @path_stack.size; end

    def find_in_search_path name
      (
        @cache_find_in_search_path[name] ||=
        [
          _find_in_search_path(name)
        ]
        ).first
    end

    def _find_in_search_path name
      RequireFaster._log "__find_in_search_path #{name.inspect}" if DEBUG[:find_in_search_path]
      case name
      when %r{\A~}
        fullpath = try_suffix(File.expand_path(name))
      when %r{\A/}
        fullpath = try_suffix(name)
      else
        fullpath = nil
        @search_path ||= $:.map{|dir| dir.dup.freeze}.freeze
        @search_path.each do | dir |
          dir = abs_path(dir)
          fullpath = try_suffix("#{dir}/#{name}")
          break if fullpath
        end
      end
      fullpath
    end

    SUFFIXES = [ '.rb', '.so' ].map!{|x| x.freeze}.freeze
    SUFFIXES_RX = SUFFIXES.map{|x| [ x, Regexp.new("#{Regexp.escape(x)}\\Z") ]}.freeze
    _SUFFIXES = ([ '' ] + SUFFIXES ).map!{|x| x.freeze}.freeze

    def try_suffix path
      RequireFaster._log "try_suffix #{path.inspect}" if DEBUG[:try_suffix]
      return path if path =~ /\.so\Z/
      # If it ends with a suffix, try it.
      SUFFIXES_RX.each do | suf, suf_rx |
        if suf_rx.match(path)
          return try_file path
        end
      end
      # Otherwise, try appending a suffix.
      SUFFIXES.each do | suf |
        if path_suf = try_file("#{path}#{suf}")
          return path_suf
        end
      end
      nil
    end

    def try_file path
      return path if readable_file?(try = path)
      RequireFaster._log "try_file #{path.inspect}" if DEBUG[:try_file]
      return nil
    end

    def readable_file? path
      (
        @cache_readable_file_[path.freeze] ||=
        [
          (
            s = ::File.stat(path) rescue nil
            x = s && s.file? && s.readable?
            RequireFaster._log "readable_file? #{path.inspect} => #{x.inspect}" if DEBUG[:readable_file]
            x
            )
        ]
        ).first
    end

    def abs_path path
      @cache_abs_path[path.freeze] ||=
        (
        x = ::File.expand_path(path)
        RequireFaster._log "abs_path #{path.inspect} => #{x.inspect}" if DEBUG[:abs_path]
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
      RequireFaster._log "flush_search_path! #{self}\n" if DEBUG[:flush_search_path]
      @cache_find_in_search_path.clear
      @search_path = nil
      self
    end
  end
end
