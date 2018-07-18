
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "csvsql/version"

Gem::Specification.new do |spec|
  spec.name          = "csvsql"
  spec.version       = Csvsql::VERSION
  spec.authors       = ["jiangzhi.xie"]
  spec.email         = ["xiejiangzhi@gmail.com"]

  spec.summary       = %q{Process csv with SQL.}
  spec.description   = %q{Process csv with SQL.}
  spec.homepage      = "https://github.com/xiejiangzhi/csvsql"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sqlite3", "~> 1.3.13"

  spec.add_development_dependency "bundler", "~> 1.16.a"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rubocop", '~> 0.52.1'
end
