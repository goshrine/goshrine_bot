DIR = File.dirname(__FILE__)
LIB = File.join(DIR, *%w[lib goshrine_bot.rb])
VERSION = open(LIB) { |lib|
  lib.each { |line|
    if v = line[/^\s*VERSION\s*=\s*(['"])(\d+\.\d+\.\d+)\1/, 2]
      break v
    end
  }
}

SPEC = Gem::Specification.new do |s|
  s.name = "goshrine_bot"
  s.version = VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Pete Schwamb"]
  s.email = ["pete@schwamb.net"]
  s.homepage = "http://github.com/ps2/goshrine_bot"
  s.summary = "A client to connect GTP go programs to GoShrine"
  s.description = <<-END_DESCRIPTION.gsub(/\s+/, " ").strip
  The GoShrine bot client is a library that allows you connect a local Go playing program that speaks GTP (like gnugo) to http://goshrine.com.
  END_DESCRIPTION

  s.add_dependency('eventmachine', '>= 0.12.10')
  s.add_dependency('em-http-request', '>= 1.0.0')
  s.add_dependency('faye', '>= 0.6.0')
  s.add_dependency('json', '>= 1.5.0')

  s.add_development_dependency "rspec"

  s.executables = ['goshrine_bot']

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- spec/*_spec.rb`.split("\n")
  s.require_paths = %w[lib]
end
