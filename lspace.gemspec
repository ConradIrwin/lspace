Gem::Specification.new do |s|
  s.name = "lspace"
  s.version = "0.1"
  s.platform = Gem::Platform::RUBY
  s.author = "Conrad Irwin"
  s.email = "conrad.irwin@gmail.com"
  s.homepage = "http://github.com/ConradIrwin/lspace"
  s.summary = "Provides local global storage"
  s.description = "Provides the convenience of global variables, without the safety concerns."
  s.files = `git ls-files`.split("\n")
  s.require_path = "lib"

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'pry-rescue'
  s.add_development_dependency 'pry-stack_explorer'
  s.add_development_dependency 'eventmachine'
end
