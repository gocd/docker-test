require 'rspec/core/rake_task'

def get_var(name)
  if ENV[name].to_s.strip.empty?
    raise "environment #{name} not specified!"
  else
    ENV[name]
  end
end

desc 'Run Rspec tests (spec/*_spec.rb)'
RSpec::Core::RakeTask.new(:unit) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = [].tap do |a|
    a.push('--color')
    a.push('--format documentation')
    a.push('--format h')
    a.push('--out ./rspec.html')
  end.join(' ')
end

task :pull_down_images do
  org = ENV['EXP_ORG'] || 'gocdexperimental'
  tag = get_var('GOCD_FULL_VERSION')
  ['gocd-server', 'gocd-agent-alpine-3.5', 'gocd-agent-alpine-3.6', 'gocd-agent-alpine-3.7', 'gocd-agent-centos-6', 'gocd-agent-centos-7', 'gocd-agent-debian-7',
  'gocd-agent-debian-8', 'gocd-agent-ubuntu-12.04', 'gocd-agent-ubuntu-14.04', 'gocd-agent-ubuntu-16.04'].each do |image|
    sh("docker pull #{org}/#{image}:v#{tag}")
  end
end

task :clean do
  sh('docker rmi $(docker images -q)')
end

task :default => [:pull_down_images] do
  begin
    Rake::Task['unit'].invoke
  rescue
    # do nothing
  ensure
    Rake::Task['clean'].invoke
  end
end