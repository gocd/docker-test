module SpecHelpers
  def start_container(opts={})
    system( "docker run -d  docker-gocd-server-test" )
  end

  def stop_container
    system("docker stop $(docker ps -a | grep 'docker-gocd-server-test' | awk '{print $1}' )")
    system("docker rm $(docker ps -a | grep 'docker-gocd-server-test' | awk '{print $1}' )")
  end
end