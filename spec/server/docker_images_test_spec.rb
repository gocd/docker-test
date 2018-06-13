##########################################################################
# Copyright 2018 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

require 'docker-api'
require 'rspec'
require 'json'
require 'rest-client'
require 'retries'

describe :server do
  before :all do
    all_images = Docker::Image.all
    @server_image = all_images.select {|i| i.info['RepoTags'].to_s.include? "gocd-server"}[0].id
  end

  describe 'config' do
    before :all do
      @container = Docker::Container.create('Image' => @server_image)
      @container.start
    end

    after :all do
      @container.stop
      @container.delete
    end
    it 'should expose the 8153 and 8154 as go server port and go server ssl port' do
      response = @container.json

      expect(response['NetworkSettings']['Ports']).to eq({'8153/tcp' => nil, '8154/tcp' => nil})
    end
  end

  describe 'port mapping and volume mounts' do
    before :all do
      FileUtils.cp_r 'spec/server/local', './tmp'
      if File.exist?('/etc/os-release')
        fail 'Failed to chown to UID 1000' unless system('sudo chown -R 1000:1000 ./tmp/*')
      end
      @container = Docker::Container.create('Image' => @server_image)
      @container.start({'Binds' => ["#{File.expand_path('./tmp')}:/godata:rw"], 'PortBindings' => {'8153/tcp' => [{'HostPort' => '8253'}], '8154/tcp' => [{'HostPort' => '8254'}]}})
      verify_go_server_is_up
    end

    after :all do
      @container.stop
      @container.delete
      fail 'Failed to cleanup tmp directory' unless system('sudo rm -rf ./tmp')
    end

    it 'should have /godata and /go-working-dir' do
      response = @container.exec(['ls'])
      result = response[0][0]
      exit_code = response[2]

      expect(exit_code).to eq(0)
      expect(result).to include("go-working-dir")
      expect(result).to include("godata")
    end

    it 'should make the go-server available on host\'s 8253 port' do
      response = ''
      with_retries(max_tries: 10, base_sleep_seconds: 10, max_sleep_seconds: 10, handler: retry_handler) {
        response = RestClient.get 'http://0.0.0.0:8253/go'
      }
      expect(response.code).to eq(200)
    end

    it 'should start the go-server with given configuration' do
      response = ''
      with_retries(max_tries: 10, base_sleep_seconds: 10, max_sleep_seconds: 10, handler: retry_handler) {
        response = RestClient.get('http://0.0.0.0:8253/go/api/admin/pipelines/up42', {'Accept' => 'application/vnd.go.cd.v5+json'})
      }

      expect(response.code).to eq(200)
    end

    it 'should provide access to the config and data directories on the host machine' do
      expect(Dir.entries('./tmp')).to include(*['addons', 'config', 'db', 'logs', 'plugins', 'artifacts'])
    end
  end

  describe 'environment variables' do
    before :all do
      @container = Docker::Container.create('Image' => @server_image, 'HostConfig' => {'PortBindings' => {'8153/tcp' => [{'HostPort' => '8253'}], '8154/tcp' => [{'HostPort' => '8254'}]}}, 'Env' => ['SERVER_MEM=1g', 'SERVER_MAX_MEM=2g'])
      @container.start
      verify_go_server_is_up
    end

    after :all do
      @container.stop
      @container.delete
    end

    it 'should pass along the env vars to the go-server process if they are the recognized by go server' do
      response = @container.top

      # response[x]['CMD']works only on linux, response[x]['COMMAND'] works on mac
      command = response[1]['CMD'] ? response[1]['CMD'] : response[1]['COMMAND']
      expect(command).to include('-Xms1g -Xmx2g')
    end
  end
end

describe :functionality do
  before :all do
    @all_images = Docker::Image.all
    server_image = @all_images.select { |i| i.info['RepoTags'].to_s.include? "gocd-server" }[0].id
    FileUtils.cp_r 'spec/server/local', './tmp'
    if File.exist?('/etc/os-release')
      fail 'Failed to chown to UID 1000' unless system('sudo chown -R 1000:1000 ./tmp/*')
    end

    @server_container = Docker::Container.create('Image' => server_image)
    @server_container.start({'Binds' => ["#{File.expand_path('./tmp')}:/godata:rw"], 'PortBindings' => {'8153/tcp' => [{'HostPort' => '8253'}], '8154/tcp' => [{'HostPort' => '8254'}]}})
    server_ip = @server_container.json['NetworkSettings']['IPAddress']
    @go_server_url = "https://#{server_ip}:8154/go"
    verify_go_server_is_up
  end

  after :all do
    @server_container.stop
    @server_container.delete
    fail 'Failed to cleanup tmp directory' unless system('sudo rm -rf ./tmp')
  end

  describe 'user provided plugins' do
    it 'should list the plugins provided by user' do
      response = RestClient.get 'http://0.0.0.0:8253/go/api/admin/plugin_info', {'Accept' => 'application/vnd.go.cd.v4+json'}
      plugin_infos = JSON.parse(response)["_embedded"]["plugin_info"]

      plugin_ids = plugin_infos.map() { |plugin_info| plugin_info["id"] }

      expect(plugin_ids).to include(*['github.pr'])
    end
  end

  describe 'work assignment and completion' do
    before :all do
      headers={accept: 'application/vnd.go.cd.v5+json', content_type: 'application/json'}
      data = pipeline_configuration
      response = RestClient.post('http://0.0.0.0:8253/go/api/admin/pipelines', data.to_json, headers)

      expect(response.code).to eq(200)

      agent_images = @all_images.select { |i| i.info['RepoTags'].to_s.include? "gocd-agent" }
      puts "The agents:  #{agent_images}"
      @containers = []
      agent_images.each_with_index do |image, index|
        @containers << Docker::Container.create('Image' => image.id, 'Env' => ["GO_SERVER_URL=#{@go_server_url}", "AGENT_AUTO_REGISTER_KEY=041b5c7e-dab2-11e5-a908-13f95f3c6ef6", "AGENT_AUTO_REGISTER_HOSTNAME=host-#{index}"])
      end

      response = RestClient.post('http://0.0.0.0:8253/go/api/pipelines/new_pipeline/unpause', {}, {'Confirm' => true})
      expect(response.code).to eq(200)
    end

    it 'should run the build on all agents' do
      @containers.each_with_index do |container, index|
        container.start
        agent_desc = container.json['Config']['Labels']['description']
        puts "Agent: #{agent_desc}"
        response = RestClient.post('http://0.0.0.0:8253/go/api/pipelines/new_pipeline/schedule', {}, {'Confirm' => true})
        expect(response.code).to eq(202)

        with_retries(max_tries: 5, base_sleep_seconds: 20, max_sleep_seconds: 20, handler: retry_handler, rescue: RestClient::Exception) {
          response = RestClient.get "http://0.0.0.0:8253/go/api/stages/new_pipeline/stage1/instance/#{index+1}/1"
          result = JSON.parse(response)["result"]
          raise RestClient::Exception unless result.eql?('Passed')
        }

        container.stop
        container.delete
      end
    end
  end

  def pipeline_configuration
    {
        group: 'first',
        pipeline: {
            name: 'new_pipeline',
            materials: [
                {
                    type: 'git',
                    attributes: {
                        url: 'https://github.com/gocd-contrib/elastic-agent-skeleton-plugin'
                    }
                }
            ],
            stages: [
                {
                    name: 'stage1',
                    jobs: [
                        {
                            name: 'job0',
                            tasks: [
                                {
                                    type: 'exec',
                                    attributes: {
                                        command: 'ls'
                                    }
                                }
                            ]
                        }
                    ]
                }
            ]
        }
    }
  end
end

def verify_go_server_is_up
  with_retries(max_tries: 20, base_sleep_seconds: 10, max_sleep_seconds: 20, handler: retry_handler) {
    RestClient.get 'http://0.0.0.0:8253/go'
  }
end

def retry_handler
  Proc.new do |exception, attempt_number, total_delay|
    puts "Handler saw a #{exception.class}; retry attempt #{attempt_number}; #{total_delay} seconds have passed."
  end
end
