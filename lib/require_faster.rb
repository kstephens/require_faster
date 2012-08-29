if defined?(RequireFaster)
$stderr.puts "RequireFaster already loaded by #{RequireFaster.FILE} #{__FILE__}"
else
# $stderr.puts "loading #{__FILE__}"
require 'thread'

module RequireFaster
  DEBUG = { }
  (ENV['RequireFaster_DEBUG'] || '').split(',').each do | s |
    k, v = s.split('=', 2)
    v = true if v.nil?
    DEBUG[k.to_sym] = v
  end
  FILE = __FILE__
  PROGNAME = $0.dup.freeze

  def self.log; @log; end
  def self.log= x; @log = x; end
  self.log = $stderr
  def self._log msg
    msg = msg.gsub(/\n/, "\n  #   ")
    instance = ::RequireFaster::Cache.instance
    log.puts "  # RF #{PROGNAME} #{$$} #{Thread.current.object_id} #{instance.depth} #{msg}"
  end

  def self.activate!
    if f = ENV["RequireFaster_LOG"]
      self.log = File.open(f, "a+")
      self.log.sync = true
    end
    PathWatcher.activate!
    self.activate_Kernel!
    if DEBUG[:activate]
      _log "activate!: DONE."
      _log "$: => #{$:.inspect}"
      _log "$\" => #{$".inspect}" #"
    end
    ($" + [ FILE ]).each do | name |
      if path = ::RequireFaster::Cache.instance.find_in_search_path(name)
        unless LOADED_PATH[path]
          LOADED_PATH[path] = name
          LOADED_NAME[name] = path
          $".unshift path unless $".include?(path)
        end
      else
        _log "warning: can't find #{name.inspect} in primoridal $LOAD_PATH"
      end
    end
      _log "Primoridal \$\"::\n#{$" * "\n"}\n" #"
    self
  end

  LOADED_PATH = { }
  LOADED_NAME = { }
  LOADED_MUTEX = Mutex.new

  module KernelMethods
    def require_faster name
      Thread.current[:'RequireFaster.exc'] = nil
      do_load = false
      instance = ::RequireFaster::Cache.instance
      RequireFaster._log "require_faster #{name.inspect} {" if DEBUG[:require]
      path = instance.find_in_search_path(name)
      unless path
        RequireFaster._log "LoadError name #{name.inspect}" if DEBUG[:require_load_error]
        RequireFaster._log "LoadError path::\n#{$: * "\n"}" if DEBUG[:require_fail_path]
        RequireFaster._log "LoadError path_stack::\n#{instance.path_stack.reverse * "\n"}\n" if DEBUG[:require_fail_path_stack]
        raise LoadError, "no such file to load -- #{name}"
      else
        RequireFaster._log "found #{path.inspect}" if DEBUG[:require_found]
      end
      LOADED_MUTEX.synchronize do
        unless LOADED_PATH[path] or LOADED_NAME[name]
          LOADED_PATH[path] = name
          LOADED_NAME[name] = path
          # Do not load, if it was required before require_faster was activated.
          do_load = ! ($".include?(name) || $".include?(path))
        end
      end
      if do_load
        RequireFaster._log "loading #{path.inspect} {::\nname #{name.inspect}" if DEBUG[:require_loading]
        RequireFaster._log "loading from::\n#{caller * "\n"}" if DEBUG[:require_caller]
        result = nil
        begin
          instance.path_stack.push path
          if path =~ /\.so\Z/
            # cant use load for .so!!
            # dont use found path for .so!!
            result = require_without_require_faster(name)
          else
            result = require_without_require_faster(name)
            #result = load(path)
          end
          # Emulate rb_provide_feature.
          $".push(name) unless $"[-1] == name || $".include?(name)
          $".push(path) unless $"[-1] == path || $".include?(path)
          result = true
        rescue SeenException
          raise
        rescue ::Exception => exc
          Thread.current[:'RequireFaster.exc'] = exc
          exc.extend SeenException
          RequireFaster._log "error #{exc.inspect} path_stack::\n#{instance.path_stack.reverse * "\n"}"
          raise exc
        end
        result
      else
        false
      end
    ensure
      if do_load
        instance.path_stack.pop
        if DEBUG[:require_loading]
          msg = "loading #{path.inspect} }"
          if exc = Thread.current[:'RequireFaster.exc']
            msg << "::\n(because #{exc.inspect})"
          end
          RequireFaster._log msg
        end
      end
      if DEBUG[:require]
        msg = "require_faster #{name.inspect} }"
        if exc = Thread.current[:'RequireFaster.exc']
          msg << "::\n(because #{exc.inspect})"
        end
        RequireFaster._log msg
      end
    end

    module SeenException; end
  end

  def self.activate_Kernel!
    Kernel.module_eval do
      include KernelMethods
      alias :require_without_require_faster :require
      alias :require :require_faster
    end
    self
  end
end
require File.expand_path('../require_faster/cache', __FILE__)
RequireFaster.activate! if (ENV['RUBYOPT'] || '') =~ /-rrequire_faster/
# $stderr.puts "loading #{__FILE__}: DONE"
end

