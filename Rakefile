# encoding: utf-8

require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
  spec.verbose = true
end


# STOLEN NEARLY VERBATIM FROM MIT-LICENSED REDIS-RB
# https://github.com/redis/redis-rb
require 'rubygems'

ENV["REDIS_BRANCH"] ||= "unstable"

$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'redis/version'

REDIS_DIR = File.expand_path(File.join("..", "spec"), __FILE__)
REDIS_CNF = File.join(REDIS_DIR, "redis.spec.conf")
REDIS_PID = File.join(REDIS_DIR, "db", "redis.pid")
BINARY = "tmp/redis-#{ENV["REDIS_BRANCH"]}/src/redis-server"

task :default => :run

desc "Run tests and manage server start/stop"
task :run => [:start, :spec, :stop]

desc "Start the Redis server"
task :start => BINARY do
  sh "#{BINARY} --version"

  redis_running = \
  begin
    File.exists?(REDIS_PID) && Process.kill(0, File.read(REDIS_PID).to_i)
  rescue Errno::ESRCH
    FileUtils.rm REDIS_PID
    false
  end

  unless redis_running
    unless system("#{BINARY} #{REDIS_CNF}")
      abort "could not start redis-server"
    end
  end
end

desc "Stop the Redis server"
task :stop do
  if File.exists?(REDIS_PID)
    Process.kill "INT", File.read(REDIS_PID).to_i
    FileUtils.rm REDIS_PID
  end
end

file BINARY do
  branch = ENV.fetch("REDIS_BRANCH")

  sh <<-SH
  mkdir -p tmp;
  cd tmp;
  wget https://github.com/antirez/redis/archive/#{branch}.tar.gz -O #{branch}.tar.gz;
  tar xf #{branch}.tar.gz;
  cd redis-#{branch};
  make
  SH
end
