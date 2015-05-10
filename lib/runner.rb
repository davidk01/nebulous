require_relative '../vendor/bundle/bundler/setup'
['./errors', './config', './provisioner', './stages', './utils'].each do |relative|
  require_relative relative
end
['trollop'].each do |g|
  require g
end
# Valid action mapping. TODO: Fix this to use subcommand pattern because we should be able to do per-VM actions.
valid_actions = {
  # Clean up stuff on the open nebula side
  'garbage-collect' => lambda do |config, opts|
    provisioner = config.provisioner
    provisioner.garbage_collect
  end,
  # Just spin up VMs and don't register them
  'instantiate' => lambda do |config, opts|
    provisioner = config.provisioner
    vm_hashes = provisioner.instantiate
    pp vm_hashes
  end,
  # Spin up VMs and provision but don't register
  'provision' => lambda do |config, opts|
    provisioner = config.provisioner
    if (partition = opts[:partition])
      delta = provisioner.delta
      forking_provisioners = (1..delta).each_slice(partition).map {|slice| provisioner.forked_provisioner(slice.length)}
      pids = forking_provisioners.each_with_index.map do |p, i|
        fork do
          sleep i * 5
          vm_hashes = p.instantiate
          p.provision(vm_hashes)
        end
      end
      pids.each do |pid|
        STDOUT.puts "Waiting on child process: #{pid}."
        Process.wait(pid)
      end
    else
      vm_hashes = provisioner.instantiate
      provisioner.provision(vm_hashes)
    end
  end,
  # Spin up VMs, provision, and register them
  'replenish' => lambda do |config, opts|
    provisioner = config.provisioner
    if (partition = opts[:partition])
      delta = provisioner.delta
      forking_provisioners = (1..delta).each_slice(partition).map {|slice| provisioner.forked_provisioner(slice.length)}
      pids = forking_provisioners.each_with_index.map do |p, i|
        fork do
          sleep i * 5
          vm_hashes = p.instantiate
          p.provision(vm_hashes)
          p.registration(vm_hashes)
        end
      end
      pids.each do |pid|
        STDOUT.puts "Waiting on child process: #{pid}."
        Process.wait(pid)
      end
    else
      vm_hashes = provisioner.instantiate
      provisioner.provision(vm_hashes)
      provisioner.registration(vm_hashes)
    end
  end,
  # Get what exists and try to re-register it
  're-register' => lambda do |config, opts|
    provisioner = config.provisioner
    vm_hashes = provisioner.opennebula_state
    provisioner.registration(vm_hashes)
  end,
  're-provision' => lambda do |config, opts|
    provisioner = config.provisioner
    vm_hashes = provisioner.opennebula_state
    provisioner.provision(vm_hashes)
  end,
  'kill-all' => lambda do |config, opts|
    provisioner = config.provisioner
    vm_hashes = provisioner.opennebula_state
    vm_hashes.each do |vm_hash|
      vm = Utils.vm_by_id(vm_hash['ID'])
      vm.delete
    end
  end
}
opts = Trollop::options do
  opt :configuration, "Location of pool configuration yaml file",
   :required => true, :type => :string, :multi => false
  opt :action, "Type of action, e.g. #{valid_actions.keys.join(', ')}. Can be repeated several times",
   :required => true, :type => :string, :multi => true
  opt :decryption_key, "File path for the decryption key for secure configurations",
   :required => false, :type => :string, :multi => false
  opt :synthetic, "Provide a list of IP addresses to act on",
    :required => false, :type => :strings, :multi => false
  opt :partition, "Set the partition size for parallel provisioning",
   :required => false, :type => :integer, :multi => false
end
# Instantiate the objects we might need, and pass in the decryption key if there is one
config = PoolConfig.load(opts[:configuration], opts[:decryption_key])
# Uniquify the actions and verify it is something we can work with
opts[:action].uniq!
opts[:action].each do |action|
  case action
  when *valid_actions.keys
  else
    raise UnknownActionError, "Unknown action: #{action}."
  end
end
# Now go through the actions and actually perform it
opts[:action].each {|action| valid_actions[action].call(config, opts)}
