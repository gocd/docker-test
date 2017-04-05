require 'rspec/core/rake_task'

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

task :build_images do
  sh('docker build --no-cache -t docker-gocd-server-test docker-gocd-server')
  sh("cd docker-gocd-agent && bundle install && GOCD_VERSION=#{ENV['GOCD_VERSION']} GOCD_AGENT_DOWNLOAD_URL=#{ENV['GOCD_AGENT_DOWNLOAD_URL']} bundle exec rake build_image")
end

task :clean do
  sh("docker rmi $(docker images -q)")
end

task :default => [:build_images] do
  begin
    Rake::Task['unit'].invoke
  rescue
    # do nothing
  ensure
    Rake::Task['clean'].invoke
  end
end