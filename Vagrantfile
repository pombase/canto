# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

# Use a default value for settings, so we can avoid checking if it's nil
settings = Hash.new

begin
  config_file = YAML.load_file './vagrant_config.yaml'
  settings = config_file
rescue
  # couldn't find config file; fall back on default
end

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
  mkdir logs
  chown vagrant:vagrant data import_export logs
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
  
  # Disable the default shared folder
  config.vm.synced_folder ".", "/vagrant",
    disabled: true

  if settings['config_directory'] 
    config.vm.synced_folder settings['config_directory'], "/home/vagrant/canto-docker/config",
      create: true,
      type: "virtualbox"
  end

  config.vm.synced_folder ".", "/home/vagrant/canto-docker/canto",
    type: "virtualbox"

  config.vm.provision "docker"

  config.vm.provision "setup_docker_folders",
    type: "shell",
    inline: setup_docker_folders

end
