# -*- ruby -*-

require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

task :default => [:all, :test]

task :all do
  ruby %{-c lib/PageTemplate.rb}
end

task :test do
  ruby %{-w -Ilib test.rb}
end

task :oldTests do
  ruby %{-w -Ilib TC_PageTemplate.rb}
end

task :missingTests do
  filename = "../missing-tests.rb"
  sh %{cd lib && ZenTest PageTemplate.rb PageTemplate/*.rb ../test.rb > #{filename}}
  puts "Missing tests are in #{filename}"
end

task :newTests do
  filename = "test.rb"
  if File.exists?(filename)
    puts "File exists"
  else
    puts "File does not exist."
    sh %{cd lib && ZenTest PageTemplate.rb PageTemplate/*.rb > ../#{filename}}
  end
  puts "Tests are in #{filename}"
end

task :install do
  ruby %{setup.rb}
end

task :uninstall do
  puts "This is only set up for Brian's machine"
  sh %{rm -rf /usr/local/lib/ruby/site_ruby/1.8/PageTemplate}
end

task :doc do
  sh %{rdoc lib/PageTemplate.rb README.txt lib/PageTemplate/*.rb}
end

spec = Gem::Specification.new do |s|
  s.name = "PageTemplate"
  s.require_path = "lib"
  $LOAD_PATH.push s.require_path
  require s.name
  s.version          = PageTemplate::VERSION
  s.author           = "Brian Wisti"
  s.email            = "brianwisti@rubyforge.org"
  s.homepage         = "http://pagetemplate.org/"
  s.platform         = Gem::Platform::RUBY
  s.summary          = "A simple templating system for Web sites."
  s.files            = Dir.glob("**/*")
  s.autorequire      = "PageTemplate.rb"
  s.test_file        = "test.rb"
  s.has_rdoc         = true
  s.extra_rdoc_files = ["README.txt"]
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

task :gem do
  if File.exists?("CVS")
    raise RuntimeError, "Trying to make a gem in CVS directory!"
  end
  sh %{rake pkg/PageTemplate-#{spec.version}.gem}
end

task :export do
  dirname = "PageTemplate-#{PageTemplate::VERSION}"
  sh %{cvs export -D now -d #{dirname} PageTemplate}
end
