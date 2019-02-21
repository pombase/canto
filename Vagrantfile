# -*- mode: ruby -*-
# vi: set ft=ruby :

setup_docker_folders = <<-SCRIPT
  cd /home/vagrant
  if [ ! -d canto-docker ]
  then
    mkdir canto-docker
  fi
  chown vagrant:vagrant canto-docker
  cd canto-docker
  mkdir data
  mkdir import_export
  chown vagrant:vagrant data import_export
SCRIPT

Vagrant.configure("2") do |config|

  config.vm.box = "debian/stretch64"
  config.vm.box_version = "9.4.0"
  config.vm.box_check_update = false

  config.vm.define "canto-vm"
  config.vm.hostname = "canto-vm"

  config.vm.provider "virtualbox" do |v|
    v.memory = 4096
  end
  
  config.vm.network "forwarded_port", guest: 5000, host: 5000

  config.vagrant.plugins = "vagrant-vbguest"
  
  config.vm.synced_folder ".", "/vagrant",
    disabled: true
  
  config.vm.synced_folder ".", "/home/vagrant/canto-docker/canto",
    type: "virtualbox"

  config.vm.provision "docker"

  config.vm.provision "setup_docker_folders",
    type: "shell",
    inline: setup_docker_folders

end
