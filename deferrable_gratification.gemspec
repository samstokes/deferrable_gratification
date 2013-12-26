Gem::Specification.new do |gem|
  gem.name = 'deferrable_gratification'
  gem.version = '0.3.1'

  gem.summary = 'Makes evented programming easier with composition and abstraction.'
  gem.description = <<-DESC
Deferrable Gratification (DG) facilitates asynchronous programming in Ruby, by helping create abstractions around complex operations built up from simpler ones.  It helps make asynchronous code less error-prone and easier to compose.  It also provides some enhancements to the Deferrable API.

Features include:

 * a #bothback method for registering code to run on either success or failure.
 
 * a combinator library for building up complex asynchronous operations out of simpler ones.
  DESC

  gem.authors = ['Sam Stokes']
  gem.email = %w(sam@rapportive.com)
  gem.homepage = 'http://github.com/samstokes/deferrable_gratification'

  gem.license = 'MIT'

  gem.required_ruby_version = '>= 1.8.7'

  gem.add_dependency 'eventmachine', '>= 1.0.3'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'bluecloth'
  gem.add_development_dependency 'rspec', '>= 2.3.0'


  gem.files = Dir[*%w(
      lib/**/*
      LICENSE*
      README*)] & %x{git ls-files -z}.split("\0")
end
