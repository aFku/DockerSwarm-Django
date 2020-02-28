# DockerSwarm-Django

Hello. In this mini-project, I want to show you, how I deploy my Django application.
To do this I will use Docker Swarm and Django backend with MariaDB database.

## Hosts specification for Docker Swarm nodes:
- Hypervisor: VirtualBox 6.0.14
- Host OS: CentOS 8
- RAM:1GB
- CPU: 2 cores (AMD Ryzen 5 2600 6-core 3.40 GHz)
- HDD: 15GB
- Network interfaces: NAT with SSH and HTTP port translated, Internal network 10.0.0.0/24

## Cluster architecture:
- 2 Masters
- 3 Workers

## Installation:

### 1. Install CentOS only on 1 host
### 2. Configure OS:
  - Change hostname
  ```
  vi (or other text editor) /etc/hostname
  #clear line and add:
  Master1.localdomain 
  ```
  - Add hostnames of other nodes with their IP to /etc/hosts:
  ```
  vi /etc/hosts
  127.0.0.1 localhost
  ::1 localhost
  Master1 10.0.0.1
  Master2 10.0.0.2
  Worker1 10.0.0.3
  Worker2 10.0.0.4
  Worker3 10.0.0.5
  ```
  - Set up static IP for internal network interface (In my case it is second interface):
  ```
  vi /etc/sysconfig/network-scripts/ifcfg-enp0s8
  BOOTPROTO=static
  ONBOOT=yes
  IPADDR=10.0.0.1
  NETMASK=255.255.255.0
  ```
  - Set up ONBOOT for NAT interface:
  ```
  vi /etc/sysconfig/network-scripts/ifcfg-enp0s3
  ONBOOT=yes
  ```
  - Open ports 8080/tcp - HTTP, 5000/tcp - Docker image registry, 2376,7946,2377/tcp and 4789,7946/udp - Docker Swarm with firewall-cmd on each node:
  ```
  firewall-cmd --zone=public --permanent --add-port=8080/tcp
  firewall-cmd --zone=public --permanent --add-port=5000/tcp
  firewall-cmd --zone=public --permanent --add-port=2376/tcp 
  firewall-cmd --zone=public --permanent --add-port=7946/tcp
  firewall-cmd --zone=public --permanent --add-port=2377/tcp
  firewall-cmd --zone=public --permanent --add-port=7946/udp
  firewall-cmd --zone=public --permanent --add-port=4789/udp
  ```
  - Disable SELINUX:
  ```
  vi /etc/selinux/config
  SELINUX=disabled
  ```
  - Add PS1 to your .bashrc if you want :) :
  ```
  vi /home/<username>/.bashrc    or    vi /root/.bashrc
  PS1="<your code>"
  # In my case: PS1="\[\e[32;40m\]\u\[\e[m\]\[\e[34m\]@\[\e[m\]\[\e[31;40m\]\h\[\e[m\][\[\e[34;40m\]\w\[\e[m\]]_: "
  ```
  - reboot machine to apply network, hostname and SELINUX changes
  - Add Docker repository to your dnf repo list:
  ```
  dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
  ```
  - Install Docker-CE with dnf:
  ```
  dnf install docker-ce --nobest -y
  ```
  - Enable and run Docker in systemctl:
  ```
  systemctl enable docker
  systemctl start docker
  ```
  Congratulations, you configured first node of our Docker Swarm cluster. Next nodes will be easier because, we will clone this one
  and only make some modification in system.
  
  ### 3. Create other nodes:
  Go to your hypervisor and just clone 4 times Master1. Change names of cloned machines. Do not forget about changing SSH and HTTP ports in NAT settings. In my case:
```
Master1 - 127.0.0.1:2222,8080 ---> Master1:22,8080
Master2 - 127.0.0.1:2223,8081 ---> Master2:22,8080
Worker1 - 127.0.0.1:2224,8082 ---> Worker1:22,8080
Worker2 - 127.0.0.1:2225,8083 ---> Worker2:22,8080
Worker3 - 127.0.0.1:2226,8084 ---> Worker2:22,8080
```
This configuration allow us to access ports 22 and 8080 using only loopback address on hypervisor host.

  On each node You have to change IP of internal network interface according lines we add to /etc/hosts on Master1 and change hostname in /etc/hostname, as we did this before.
  
  ### 4. Create Docker Swarm cluster:
  - On Master1 you have to execute command:
  ```
  docker swarm init --advertise-addr 10.0.0.1
  ```  
  It will initalize docker cluster and create token which we will use to add workers.
  - Join worker o cluster, by executing command on worker node:
  ```
  docker swarm join --token <your token> 10.0.0.1:2377
  ```
  - Execute below command on Master1:
  ```
  docker swarm join-token manager
  ```
  Copy new token and add Master2 to cluster as secondary manager:
  ```
  docker swarm join --token <your new manager token> 10.0.0.1:2377
  ```
  
  
  Now we have working cluster with 2 managers and 3 workers. Congratulations :)
  
  ### 5. Create registry service:
  Now we will set up unsecured registry service to share images among other nodes with HTTP protocol.
  - To use HTTP insted HTTPS (which is default protocol to share images) we need add nodes with registry service to "insecure-registries"  group. We will host registry only on manager nodes, so in /etc/docker/daemon.json we have to add following lines (if daemon.json doesn't exists there, just create it) on all nodes:
  ```
  vi /etc/docker/daemon.json
  {
    "insecure-registries" : ["Master1:5000", "Master2:5000"]
  }
  ```
  after that, restart docker service with systemctl:
  ```
  systemctl restart docker
  ```
  - create registry service:
  ```
  docker service create --name registry --publish=5000:5000 --constraint=node.role==manager registry:latest
  ```
  ### 6. Prepare Django app for containerization:
  Everything what you will see in this paragraph, must be done on Master node.
  - If your system release doesn't contain git commands, install they with:
  ```
  dnf install git -y
  ```
  - Download app from my repo:
  ```
  git clone https://github.com/aFku/Django-MultiApp.git
  ```
  - Download wait-for-it.sh bash script from vishnubob's repo from https://github.com/vishnubob/wait-for-it . This script won't let Django app be started before Database:
  ```
  git clone https://github.com/vishnubob/wait-for-it.git
  cp wait-for-it/wait-for-it.sh .
  rm -rf wait-for-it
  ```
  - Get dockerfile from current repository, build it and push it to registry:
  ```
  git clone https://github.com/aFku/DockerSwarm-Django.git
  cp DockerSwarm-Django/dockerfile .
  docker image build -t Master1:5000/questionsite .
  docker push Master1:5000/questionsite
  ```
  It is necessarily to store Django-MultiApp dir, dockerfile and wait-for-it.sh in one directory.
  
  ### 7. Deploying
  -First create new overlay network for 12communication beetwen nodes:
  ```
  docker network create --driver overlay site
  ```
  -To deploy our stack, go to DockerSwarm-Django directory and execute command:
  ```
  docker stack deploy --compose-file=site_swarm.yml django-stack
  ```
  -Now to check on which node tasks were deployed run:
  ```
  docker stack ps django-stack
  ```
  ### 8. Verification
  - Go to hypervisor's host, open browser and type follow line in url field for each node:
  ```
  127.0.0.1:<node's translated http port>/News
  ```
  Each time you should see website made with Django framework.
  
  ## Plans for the future:
  - Common storage for many database instances (maybe with sshfs)
  - Add NGINX as a web server
  
  


  
  
