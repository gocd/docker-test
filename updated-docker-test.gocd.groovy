
GoCD.script {
  pipelines {
    pipeline('updated-docker-test') {
      group = 'cloud'
      labelTemplate = '${COUNT}'
      lockBehavior = 'none'
      secureEnvironmentVariables = [
        TOKEN: 'AES:xCrEdvPdvCRL0C7LJzgqnw==:ziiRL2A7a/dfWkecgzxp4Eea01eN5efqGPru4pe4zplzrtsOPy6JiZBy1KOKLxETwGDwltNMo/eg0ohJ3FLVHA==',
      ]
      materials {
        git('docker-repo') {
          branch = 'master'
          destination = 'docker-test'
          shallowClone = false
          url = 'https://git.gocd.io/git/gocd/docker-test'
        }
        dependency('code-sign') {
          pipeline = 'code-sign'
          stage = 'metadata'
        }
        git('docker-gocd-server') {
          branch = 'master'
          destination = 'docker-gocd-server'
          shallowClone = false
          url = 'https://git.gocd.io/git/gocd/docker-gocd-server'
        }
        git('docker-gocd-server-centos-7') {
          branch = 'master'
          destination = 'docker-gocd-server-centos-7'
          shallowClone = false
          url = 'https://git.gocd.io/git/gocd/docker-gocd-server-centos-7'
        }
        git('docker-gocd-agent') {
          branch = 'master'
          destination = 'docker-gocd-agent'
          shallowClone = false
          url = 'https://git.gocd.io/git/gocd/docker-gocd-agent'
        }
      }
      stages {
        stage('BuildDockerImages') {
          artifactCleanupProhibited = false
          cleanWorkingDir = false
          fetchMaterials = true
          approval {
          }
          jobs {
            job('ServerDockerImage') {
              elasticProfileId = 'ecs-docker-in-docker'
              runInstanceCount = '1'
              timeout = 0
              tasks {
                exec {
                  commandLine = ['bash', '-c', 'sudo dvm install']
                  runIf = 'passed'
                  workingDir = 'docker-gocd-server'
                }
                fetchArtifact {
                  destination = 'docker-gocd-server'
                  file = true
                  job = 'dist'
                  pipeline = 'installers/code-sign'
                  runIf = 'passed'
                  source = 'dist/meta/version.json'
                  stage = 'dist'
                }
                exec {
                  commandLine = ['bash', '-c', 'rake docker_push_experimental']
                  runIf = 'passed'
                  workingDir = 'docker-gocd-server'
                }
              }
            }
            job('ServerDockerImageCentOS7') {
              elasticProfileId = 'ecs-docker-in-docker'
              runInstanceCount = '1'
              timeout = 0
              tasks {
                exec {
                  commandLine = ['bash', '-c', 'sudo dvm install']
                  runIf = 'passed'
                  workingDir = 'docker-gocd-server-centos-7'
                }
                fetchArtifact {
                  destination = 'docker-gocd-server-centos-7'
                  file = true
                  job = 'dist'
                  pipeline = 'installers/code-sign'
                  runIf = 'passed'
                  source = 'dist/meta/version.json'
                  stage = 'dist'
                }
                exec {
                  commandLine = ['bash', '-c', 'rake docker_push_experimental']
                  runIf = 'passed'
                  workingDir = 'docker-gocd-server-centos-7'
                }
              }
            }
            job('AgentDockerImages') {
              elasticProfileId = 'ecs-docker-in-docker'
              runInstanceCount = '4'
              timeout = 0
              tasks {
                exec {
                  commandLine = ['bash', '-c', 'sudo dvm install']
                  runIf = 'passed'
                  workingDir = 'docker-gocd-agent'
                }
                fetchArtifact {
                  destination = 'docker-gocd-agent'
                  file = true
                  job = 'dist'
                  pipeline = 'installers/code-sign'
                  runIf = 'passed'
                  source = 'dist/meta/version.json'
                  stage = 'dist'
                }
                exec {
                  commandLine = ['bash', '-c', 'rake docker_push_experimental']
                  runIf = 'passed'
                  workingDir = 'docker-gocd-agent'
                }
              }
            }
          }
        }
        stage('test') {
          artifactCleanupProhibited = false
          cleanWorkingDir = false
          fetchMaterials = true
          approval {
          }
          jobs {
            job('test') {
              elasticProfileId = 'ecs-docker-in-docker'
              runInstanceCount = '4'
              timeout = 0
              artifacts {
                build {
                  destination = 'result'
                  source = 'docker-test/rspec.html'
                }
              }
              tasks {
                exec {
                  commandLine = ['bash', '-c', 'sudo gem install bundler --no-ri --no-rdoc && sudo bundle install && sudo dvm install']
                  runIf = 'passed'
                  workingDir = 'docker-test'
                }
                fetchArtifact {
                  destination = 'docker-test'
                  file = true
                  job = 'dist'
                  pipeline = 'Installers/code-sign'
                  runIf = 'passed'
                  source = 'dist/meta/version.json'
                  stage = 'dist'
                }
                exec {
                  commandLine = ['bash', '-c', 'bundle exec rake']
                  runIf = 'passed'
                  workingDir = 'docker-test'
                }
              }
            }
          }
        }
      }
    }
  }
}

