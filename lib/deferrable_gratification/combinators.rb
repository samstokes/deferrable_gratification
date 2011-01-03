Dir.glob(File.join(File.dirname(__FILE__), *%w[combinators *.rb])) do |file|
  require file.sub(/\.rb$/, '')
end

module DeferrableGratification
  module Combinators
  end
end
