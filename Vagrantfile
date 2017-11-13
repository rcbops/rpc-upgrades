########################################
### rpc-upgrades
###
### vagrantfile for testing rpc-upgrades
###
### usage: vagrant up <leapfrog_to_test>
########################################

# Verify whether required plugins are installed.
required_plugins = [ "vagrant-disksize" ]
required_plugins.each do |plugin|
  if not Vagrant.has_plugin?(plugin)
    raise "The vagrant plugin #{plugin} is required. Please run `vagrant plugin install #{plugin}`"
  end
end

Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox" do |v|
    v.memory = 16384
    v.cpus = 4
  end

  # Configure the disk size.
  disk_size = "100GB"

  ### vagrant up liberty_to_newton
  config.vm.define "liberty_to_newton" do |liberty_to_newton|
    liberty_to_newton.vm.box = "ubuntu/trusty64"
    liberty_to_newton.disksize.size = disk_size
    liberty_to_newton.vm.hostname = "liberty"
    config.vm.provision "shell",
      privileged: true,
      inline: <<-SHELL
          sudo su -
          apt update
          apt-get -y install git build-essential gcc libssl-dev libffi-dev python-dev
          git clone https://github.com/rcbops/rpc-upgrades.git /opt/rpc-upgrades
          cd /opt/rpc-upgrades
          RE_JOB_SERIES=liberty ./run-tests.sh
      SHELL
  end

  ### vagrant up r12.2.8_to_newton
  config.vm.define "r12_2_8_to_newton" do |r12_2_8_to_newton|
    r12_2_8_to_newton.vm.box = "ubuntu/trusty64"
    r12_2_8_to_newton.disksize.size = disk_size
    r12_2_8_to_newton.vm.hostname = "r12.2.8"
    config.vm.provision "shell",
      privileged: true,
      inline: <<-SHELL
          sudo su -
          apt update
          apt-get -y install git build-essential gcc libssl-dev libffi-dev python-dev
          git clone https://github.com/rcbops/rpc-upgrades.git /opt/rpc-upgrades
          cd /opt/rpc-upgrades
          RE_JOB_SERIES=liberty RE_JOB_CONTEXT=r12.2.8 ./run-tests.sh
      SHELL
  end

  ### vagrant up kilo_to_newton
  config.vm.define "kilo_to_newton" do |kilo_to_newton|
    kilo_to_newton.vm.box = "ubuntu/trusty64"
    kilo_to_newton.disksize.size = disk_size
    kilo_to_newton.vm.hostname = "kilo"
    config.vm.provision "shell",
      privileged: true,
      inline: <<-SHELL
          sudo su -
          apt update
          apt-get -y install git build-essential gcc libssl-dev libffi-dev python-dev
          git clone https://github.com/rcbops/rpc-upgrades.git /opt/rpc-upgrades
          cd /opt/rpc-upgrades
          RE_JOB_SERIES=kilo ./run-tests.sh
      SHELL
  end

end
