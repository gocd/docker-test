require 'fileutils'
require 'json'

class ConsoleLogger
  def self.info message
    puts "\e[1;34m[INFO]\e[0m #{message}"
  end

  def self.warn message
    puts "\e[1;33m[WARN]\e[0m #{message}"
  end

  def self.error message
    puts "\e[1;31m[ERROR]\e[0m #{message}"
  end
end

def versionFile(key)
  version_file_location = ENV["VERSION_FILE_LOCATION"] || 'version.json'
  ConsoleLogger.info "Reading #{key} from file #{version_file_location}."
  value = JSON.parse(File.read(version_file_location))[key]
  ConsoleLogger.info "Detected value for #{key} is #{value}."
  value
end

class Docker
  def self.login
    raise "Environment variable TOKEN is not specified." unless TOKEN
    ConsoleLogger.info "User home directory is #{Dir.home}"
    FileUtils.mkdir_p "#{Dir.home}/.docker"
    File.open("#{Dir.home}/.docker/config.json", "w") do |f|
      f.write({:auths => {"https://index.docker.io/v1/" => {:auth => TOKEN}}}.to_json)
    end
    ConsoleLogger.info "Docker config.json file is successfully created."
  end

  def self.logout
    FileUtils.rm_r "#{Dir.home}/.docker"
  end
end

class Environment
  @env_hash = {}

  def self.env(name, value)
    @env_hash[name] = value
    self
  end

  def self.to_s
    @env_hash.map {|k, v| "#{k}=#{v}"}.join(" ")
  end
end
