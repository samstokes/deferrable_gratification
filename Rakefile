require 'rspec/core/rake_task'
require 'yard'

namespace :spec do
  RSpec::Core::RakeTask.new(:default)

  desc 'Describe behaviour by running RSpec code examples'
  RSpec::Core::RakeTask.new(:doc) do |t|
    t.rspec_opts = '--format documentation'
  end
end
task :spec => 'spec:default'

YARD::Rake::YardocTask.new(:doc)

task :default => :spec
