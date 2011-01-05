Gem::Specification.new do |gem|
  gem.name = 'deferrable_gratification'
  gem.version = '0.0.3'

  gem.summary = 'Makes Ruby Deferrables nicer to work with.'
  gem.description = <<-DESC
Makes Ruby Deferrables nicer to work with.

Currently consists of the following components:

 * fluent (aka chainable) syntax for registering multiple callbacks and errbacks to the same Deferrable.

 * a #bothback method for registering code to run on either success or failure.
 
 * a combinator library for building up complex asynchronous operations out of simpler ones.
  DESC

  gem.authors = ['Sam Stokes']
  gem.email = %w(sam@rapportive.com)
  gem.homepage = 'http://github.com/samstokes/deferrable_gratification'


  gem.required_ruby_version = '>= 1.8.7'

  gem.add_dependency 'eventmachine'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'bluecloth'
  gem.add_development_dependency 'rspec', '>= 2.3.0'


  gem.files = Dir[*%w(
      lib/**/*
      README*)] & %x{git ls-files -z}.split("\0")
end
