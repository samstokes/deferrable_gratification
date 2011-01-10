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
desc 'Run RSpec code examples'
task :spec => 'spec:default'

namespace :doc do
  doc_dir = File.join(File.dirname(__FILE__), 'doc')

  YARD::Rake::YardocTask.new(:api)

  desc 'Generate HTML behaviour documentation from the specs'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.fail_on_error = false   # just make the damn docs
    t.rspec_opts = "--format html --out #{File.join(doc_dir, 'spec', 'index.html')}"
  end

  desc 'Remove all generated documentation'
  task :clobber do
    system("git clean -fdx #{doc_dir}") or fail 'failed to clean doc/'
  end

  desc 'Clear out any cruft and regenerate HTML documentation'
  task :regen => [:clobber, :all]

  desc 'Generate all HTML documentation'
  task :all => [:api, :spec]
end
desc 'Generate HTML documentation'
task :doc => 'doc:all'

gemspec_file = Dir[File.join(File.dirname(__FILE__), '*.gemspec')].first or raise "Couldn't find gemspec"
gemspec = Gem::Specification.load(gemspec_file)
Rake::GemPackageTask.new(gemspec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

task :default => :spec
