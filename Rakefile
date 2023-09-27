require 'rubygems'
require 'bundler'
require 'rake/testtask'
require 'dotenv'
Dotenv.load('.env.test')

Rake::TestTask.new :test do |t|
  t.libs << 'test' << 'app'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

task default: :test
