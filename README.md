# jenkins_docker
jenkins_docker


Static IP for docker image for windows docker

#Setup a NAT
https://docs.microsoft.com/en-us/virtualization/windowscontainers/container-networking/network-drivers-topologies

docker network create -d "nat" --subnet "10.244.0.0/24" my_nat

#building a container
docker build -t vs2019_jenkins_master1 .

#Create and run a container
docker run -it --net my_nat --ip 10.244.0.8 -v c:\jenkins:c:\jenkins --name jenkins_master vs2019_jenkins_master1
