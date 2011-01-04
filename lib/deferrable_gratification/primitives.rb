Dir.glob(File.join(File.dirname(__FILE__), *%w[primitives *.rb])) do |file|
  require file.sub(/\.rb$/, '')
end

module DeferrableGratification
  module Primitives
    def const(value)
      Constant.new(value)
    end

    def failure(*args)
      Failure.new(*args)
    end
  end
end
