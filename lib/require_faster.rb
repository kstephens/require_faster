$stderr.puts "loading #{__FILE__}"
module RequireFaster
  def self.activate!
    PathWatcher.activate!
    self.activate_Kernel!
    self
  end
  def self.activate_Kernel!
    Kernel.module_eval do
      def require_faster name
        path = ::RequireFaster::Cache.instance.find_in_search_path(name)
        require_without_require_faster path
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

