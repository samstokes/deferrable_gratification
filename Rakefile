require 'rspec/core/rake_task'
require 'yard'
require 'rake/gempackagetask'

namespace :spec do
  RSpec::Core::RakeTask.new(:default)

  desc 'Describe behaviour by running RSpec code examples'
  RSpec::Core::RakeTask.new(:doc) do |t|
    t.rspec_opts = '--format documentation'
  end

  # support for continuous integration
  begin
    gem 'ci_reporter', :version => '>= 1.6.4'
    require 'ci/reporter/rake/rspec'

    task :setup_ci_report_dir do
      ENV['CI_REPORTS'] = 'doc/spec/reports'
    end

    desc 'Run all specs in spec directory outputting CI-friendly XML reports'
    task :ci => [:setup_ci_report_dir, 'ci:setup:rspec', :default]
  rescue LoadError => le
    desc '(DISABLED) Run all specs in spec directory outputting CI-friendly XML reports'
    task :ci do raise le end
  end
end
desc 'Run RSpec code examples'
task :spec => 'spec:default'

namespace :doc do
  doc_dir = File.join(File.dirname(__FILE__), 'doc')

  namespace :api do
    desc 'Generate HTML documentation for the public API'
    YARD::Rake::YardocTask.new(:public) do |t|
      t.options = ['--no-private']
    end

    desc 'Generate HTML documentation for implementers, including privates'
    YARD::Rake::YardocTask.new(:private)
  end
  desc 'Generate HTML API documentation'
  task :api => 'api:public'

  desc 'Generate HTML behaviour documentation from the specs'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.fail_on_error = false   # just make the damn docs
    t.rspec_opts = "--format html --out #{File.join(doc_dir, 'spec', 'index.html')}"
  end

  desc 'Remove all generated documentation'
  task :clobber do
    git :clean, '-fdx', doc_dir
  end

  desc 'Clear out any cruft and regenerate HTML documentation'
  task :regen => [:clobber, :all]

  desc 'Publish docs to Github Pages'
  task :publish => :regen do
    current_branch = `git describe --contains --all HEAD`.strip
    fail "Couldn't determine current branch" if current_branch.empty?

    begin
      git :stash
      git :checkout, '--merge', 'gh-pages'
      git :add, doc_dir
      git :commit, '-v', doc_dir
      git :push, :github, 'gh-pages'
    ensure
      git :checkout, current_branch
      git :stash, :pop
    end
  end

  desc 'Generate all HTML documentation'
  task :all => [:api, :spec]
end
desc 'Generate HTML documentation'
task :doc => 'doc:all'

def shell(cmd)
  system(cmd) or raise "Command failed: #{cmd}"
end

def gemspec_file() Dir[File.join(File.dirname(__FILE__), '*.gemspec')].first or raise "Couldn't find gemspec" end
def gemspec() Gem::Specification.load(gemspec_file) end
namespace :package do
  Rake::GemPackageTask.new(gemspec) do |pkg|
    pkg.need_zip = true
    pkg.need_tar = true
  end
end
namespace :gem do
  desc 'Build the gem file'
  task :build => '^package:gem'

  desc 'Rebuild the gem file cleanly'
  task :rebuild => ['^package:clobber_package', :build]

  desc 'Publish rebuilt gem to RubyGems.org'
  task :publish => :rebuild do
    shell 'gem push pkg/deferrable_gratification*.gem'
  end
end
task :gem => 'package:gem'

namespace :version do
  namespace :bump do
    SEGMENTS = %w(major minor patch)
    SEGMENTS.each do |segment|
      desc "Bump #{segment} version number"
      task(segment) { bump(segment) }
    end
    def bump(segment)
      segment_index = SEGMENTS.index(segment)
      raise ArgumentError unless segment_index
      old_version = gemspec.version.to_s
      segments = gemspec.version.segments
      segments[segment_index] += 1
      new_version = segments.join('.')
      shell "sed -i '/gem\\.version/s/#{old_version.gsub('.', '\.')}/#{new_version}/' #{gemspec_file}"
      puts "Bumped version from #{old_version} to #{new_version}"
    end
  end
end

task :default => :spec


def git(command, *args)
  system('git', command.to_s, *args.map(&:to_s)) or raise "'git #{command} #{args.join(' ')}' failed!"
end
