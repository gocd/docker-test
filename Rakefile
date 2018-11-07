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
AGENT_DOCKER_IMAGES = ['gocd-agent-alpine-3.6', 'gocd-agent-alpine-3.7', 'gocd-agent-alpine-3.8', 'gocd-agent-centos-6', 'gocd-agent-centos-7', 'gocd-agent-debian-8', 'gocd-agent-debian-9', 'gocd-agent-docker-dind', 'gocd-agent-ubuntu-14.04', 'gocd-agent-ubuntu-16.04', 'gocd-agent-ubuntu-18.04', 'docker-gocd-agent-fedora-28', 'docker-gocd-agent-fedora-29']

total_workers = (ENV['GO_JOB_RUN_COUNT'] || '1').to_i
image_to_test_per_worker = (AGENT_DOCKER_IMAGES.length.to_f / total_workers).ceil
current_worker_index = (ENV['GO_JOB_RUN_INDEX'] || '1').to_i
images_to_test = AGENT_DOCKER_IMAGES.each_slice(image_to_test_per_worker).to_a[current_worker_index - 1]


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

task :pull_down_image, [:image] do |task, args|
  ConsoleLogger.info "Pulling image #{args[:image]}."
  org = ENV['EXP_ORG'] || 'gocdexperimental'
  sh("docker pull #{org}/#{args[:image]}:v#{GOCD_FULL_VERSION}")
end

task :clean do
  Docker.logout
  org = ENV['EXP_ORG'] || 'gocdexperimental'
  AGENT_DOCKER_IMAGES.each do |image|
    sh("docker rmi -f #{org}/#{image}:v#{GOCD_FULL_VERSION}")
  end
end

task :remove_image, [:image_to_remove] do |task, args|
  org = ENV['EXP_ORG'] || 'gocdexperimental'
  sh("docker rmi -f #{org}/#{args[:image_to_remove]}:v#{GOCD_FULL_VERSION}")
end

task :default do
  begin
    Docker.login
    Rake::Task[:pull_down_image].execute :image => 'gocd-server'
    images_to_test.each do |image|
      Rake::Task[:pull_down_image].execute :image => image
      Rake::Task[:unit].execute
      Rake::Task[:remove_image].execute :image_to_remove => image
    end
  rescue => e
    ConsoleLogger.error e
  ensure
    Rake::Task['clean'].invoke
  end
end

