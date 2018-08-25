require 'rspec/core/rake_task'
require 'git'
require './helper'

TOKEN = ENV['TOKEN']
ORIGINAL_DIR = Dir.getwd
TMP_WORKING_DIR = Dir.mktmpdir(nil, '/tmp')
GOCD_GIT_SHA = versionFile('git_sha')
GOCD_VERSION = ENV['GOCD_VERSION'] || versionFile('go_version')
GOCD_FULL_VERSION = ENV['GOCD_FULL_VERSION'] || versionFile('go_full_version')
MIRROR_URL = ENV['MIRROR_URL'] || 'https://git.gocd.io/git/gocd'
GOCD_SERVER_DOWNLOAD_URL = "https://download.gocd.org/experimental/binaries/#{GOCD_FULL_VERSION}/generic/go-server-#{GOCD_FULL_VERSION}.zip"
GOCD_AGENT_DOWNLOAD_URL = "https://download.gocd.org/experimental/binaries/#{GOCD_FULL_VERSION}/generic/go-agent-#{GOCD_FULL_VERSION}.zip"
DOCKER_IMAGES = ['gocd-server', 'gocd-agent-alpine-3.5', 'gocd-agent-alpine-3.6', 'gocd-agent-alpine-3.7', 'gocd-agent-centos-6', 'gocd-agent-centos-7', 'gocd-agent-debian-8', 'gocd-agent-debian-9', 'gocd-agent-docker-dind', 'gocd-agent-ubuntu-12.04', 'gocd-agent-ubuntu-14.04', 'gocd-agent-ubuntu-16.04']

task :publish_experimental do
  begin
    ConsoleLogger.info "Working directory is #{TMP_WORKING_DIR}"

    Docker.login
    env_as_string = Environment.env("GOCD_VERSION", GOCD_VERSION)
                        .env("GOCD_GIT_SHA", GOCD_GIT_SHA)
                        .env("GOCD_FULL_VERSION", GOCD_FULL_VERSION)
                        .env("GOCD_SERVER_DOWNLOAD_URL", GOCD_SERVER_DOWNLOAD_URL)
                        .env("GOCD_AGENT_DOWNLOAD_URL", GOCD_AGENT_DOWNLOAD_URL)
                        .to_s

    ['docker-gocd-server', 'docker-gocd-agent'].each do |repo|
      ConsoleLogger.info "Cloning #{repo} repo."
      Git.clone("#{MIRROR_URL}/#{repo}", repo, :path => TMP_WORKING_DIR)

      ConsoleLogger.info "Building experimental image from #{repo}."
      cd("#{TMP_WORKING_DIR}/#{repo}", verbose: true)
      sh("#{env_as_string} bundle exec rake -f Rakefile docker_push_experimental")
    end

    ConsoleLogger.info "Done."
  rescue => e
    ConsoleLogger.error e
  ensure
    cd(ORIGINAL_DIR)
    Docker.logout
    FileUtils.rm_r TMP_WORKING_DIR
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
  ConsoleLogger.info "Pulling server and agents images."
  org = ENV['EXP_ORG'] || 'gocdexperimental'
  DOCKER_IMAGES.each do |image|
    sh("docker pull #{org}/#{image}:v#{GOCD_FULL_VERSION}")
  end
end

task :clean do
  Docker.logout
  org = ENV['EXP_ORG'] || 'gocdexperimental'
  DOCKER_IMAGES.each do |image|
    sh("docker rmi -f #{org}/#{image}:v#{GOCD_FULL_VERSION}")
  end
end

task :default => [:pull_down_images] do
  begin
    Docker.login
    Rake::Task['unit'].invoke
  rescue => e
    ConsoleLogger.error e
  ensure
    Rake::Task['clean'].invoke
  end
end

