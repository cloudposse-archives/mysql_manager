# -*- encoding: utf-8 -*-
require File.expand_path('../lib/mysql_manager/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Erik Osterman"]
  gem.email         = ["e@osterman.com"]
  gem.description   = %q{MySQL Manager is a utility to perform routine tasks on a MySQL database.}
  gem.summary       = %q{MySQL Manager is a utility to perform routine tasks such as restoring replication after errors, killing queries based on a set of criteria, or reloading my.cnf without restarting the database.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "mysql_manager"
  gem.license       = "GPL3"
  gem.require_paths = ["lib"]
  gem.version       = MysqlManager::VERSION
  gem.add_runtime_dependency "parseconfig", ">= 1.0.2"
  gem.add_runtime_dependency "dbi", ">= 0.4.5"
  gem.add_runtime_dependency "dbd-mysql", ">= 0.4.4"
end
