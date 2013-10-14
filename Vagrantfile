Vagrant::Config.run do |config|

$canto_script = <<SCRIPT
if [ ! -d root-canto ]
then
  git clone /vagrant root-canto
  (cd root-canto; perl Makefile.PL < /dev/null; make)
fi

if [ ! -d canto ]
then
  su - vagrant -c '
    git clone /vagrant canto;
    (cd canto && perl Makefile.PL < /dev/null)'
fi

if [ ! -d data ]
then
  su - vagrant -c '(cd canto; ./script/canto_start --initialise ~/data && echo Canto data initialised)'
fi
SCRIPT

config.vm.box = "precise64"
  config.vm.forward_port 5000, 5500
  config.vm.provision :puppet
  config.vm.provision :shell,
    :inline => $canto_script
end

