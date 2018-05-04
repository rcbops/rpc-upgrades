########################################
### rpc-upgrades
###
### vagrantfile for testing rpc-upgrades
###
### usage: vagrant up <leapfrog_to_test>
########################################

# Verify whether required plugins are installed.
required_plugins = [ "vagrant-cachier", "vagrant-disksize" ]
required_plugins.each do |plugin|
  if not Vagrant.has_plugin?(plugin)
    raise "The vagrant plugin #{plugin} is required. Please run `vagrant plugin install #{plugin}`"
  end
end

# Configure Job Actions the way gating would pass them
job_actions = [
  "kilo_to_newton_leap",
  "kilo_to_r14.2.0_leap",
  "kilo_to_r14.11.0_leap",
  "liberty_to_newton_leap",
  "r12.1.2_to_r14.11.0_leap",
  "r12.2.2_to_r14.11.0_leap",
  "r12.2.5_to_r14.11.0_leap",
  "r12.2.8_to_r14.11.0_leap",
]

Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox" do |provider|
    provider.memory = 16384
    provider.cpus = 4
  end

  # Configure the box
  config.vm.box = "ubuntu/trusty64"
  config.vm.box_check_update = false

  # Configure the disk size.
  config.disksize.size = "100GB"

  # Configure cache options
  config.cache.scope = :box

  ### vagrant up job actions
  job_actions.each do |job_action|
    (upgrade_from, _, upgrade_to, upgrade_type) = job_action.split("_")

    config.vm.define job_action do |job|
      job.vm.hostname = upgrade_from.gsub(".", "-")
      job.vm.provision "shell",
        privileged: true,
        inline: <<-SHELL
            sudo su -
            apt update
            apt-get -y install git build-essential gcc libssl-dev libffi-dev python-dev
            ln -s /vagrant /opt/rpc-upgrades
            pushd /opt/rpc-upgrades
            export RE_JOB_ACTION="#{job_action}"
            ./run-tests.sh
        SHELL
    end
  end

end
