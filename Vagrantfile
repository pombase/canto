Vagrant::Config.run do |config|

$pomcur_script = <<SCRIPT
git clone /vagrant root-pomcur
(cd root-pomcur; perl Makefile.PL < /dev/null; make)
su - vagrant -c '
  git clone /vagrant pomcur;
  (cd pomcur && perl Makefile.PL < /dev/null && (./script/pomcur_start --initialise ~/data; ./script/pomcur_start ~/data > server.out 2> server.err & echo Canto server started) )'
SCRIPT

config.vm.box = "precise64"
  config.vm.forward_port 5000, 5500
  config.vm.provision :shell,
    :inline => 'apt-get update'
  config.vm.provision :puppet
  config.vm.provision :shell,
    :inline => $pomcur_script
end

