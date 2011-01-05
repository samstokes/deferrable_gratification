require 'rspec/core/rake_task'
require 'yard'
require 'rake/gempackagetask'

namespace :spec do
  RSpec::Core::RakeTask.new(:default)

  desc 'Describe behaviour by running RSpec code examples'
  RSpec::Core::RakeTask.new(:doc) do |t|
    t.rspec_opts = '--format documentation'
  end
end
task :spec => 'spec:default'

YARD::Rake::YardocTask.new(:doc)

gemspec_file = Dir[File.join(File.dirname(__FILE__), '*.gemspec')].first or raise "Couldn't find gemspec"
gemspec = Gem::Specification.load(gemspec_file)
Rake::GemPackageTask.new(gemspec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

task :default => :spec
