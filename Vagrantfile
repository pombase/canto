Vagrant::Config.run do |config|

$pomcur_script = <<SCRIPT
if [ ! -d root-pomcur ]
then
  git clone /vagrant root-pomcur
  (cd root-pomcur; perl Makefile.PL < /dev/null; make)
fi

if [ ! -d pomcur ]
then
  su - vagrant -c '
    git clone /vagrant pomcur;
    (cd pomcur && perl Makefile.PL < /dev/null)'
fi

if [ ! -d data ]
then
  su - vagrant -c '(cd pomcur; ./script/pomcur_start --initialise ~/data && echo Canto data initialised)'
fi
SCRIPT

config.vm.box = "precise64"
  config.vm.forward_port 5000, 5500
  config.vm.provision :puppet
  config.vm.provision :shell,
    :inline => $pomcur_script
end

