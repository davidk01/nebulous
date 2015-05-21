#!/usr/bin/env ruby
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
    id_filter = opts[:synthetic]
    if id_filter
      vm_hashes.select! {|vm| id_filter.include?(vm['ID'])}
    end
    provisioner.registration(vm_hashes)
  end,
  're-provision' => lambda do |config, opts|
    provisioner = config.provisioner
    vm_hashes = provisioner.opennebula_state
    id_filter = opts[:synthetic]
    if id_filter
      vm_hashes.select! {|vm| id_filter.include?(vm['ID'])}
    end
    provisioner.provision(vm_hashes)
  end,
  'dump-state' => lambda do |config, opts|
    provisioner = config.provisioner
    vm_hashes = provisioner.opennebula_state
    vm_hashes.each do |vm_hash|
      id = vm_hash['ID']
      name = vm_hash['NAME']
      ip = vm_hash['TEMPLATE']['NIC']['IP']
      hostname = vm_hash['TEMPLATE']['CONTEXT']['SET_HOSTNAME']
      pool = vm_hash['USER_TEMPLATE']['POOL']
      STDOUT.puts "#{id} - #{ip} - #{name} - #{hostname} - #{pool}"
    end
  end,
  # This is a dangerous operation so adding a warning message and forcing the user
  # to acknowledge they want to proceed
  'kill-all' => lambda do |config, opts|
    require 'pry'; binding.pry
    provisioner = config.provisioner
    vm_hashes = provisioner.opennebula_state
    id_filter = opts[:synthetic]
    if id_filter
      vm_hashes.select! {|vm| id_filter.include?(vm['ID'])}
    end
    unless opts[:force]
      STDOUT.puts "You are about to kill a bunch of VMs:"
      ids = vm_hashes.map {|vm_hash| vm_hash['ID']}.join(', ')
      STDOUT.puts ids
      STDOUT.write "Are you sure you want to proceed? (y/n): "
      confirmation = STDIN.gets.strip.downcase
      if confirmation.include?('n')
        STDOUT.puts "Aborting!"
        exit!
      else
        STDOUT.puts "Proceeding!"
      end
    end
    vm_hashes.each do |vm_hash|
      vm = Utils.vm_by_id(vm_hash['ID'])
      STDOUT.puts "Killing VM: #{vm_hash['ID']}."
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
  opt :synthetic, "Provide a list of IDs to act on",
    :required => false, :type => :strings, :multi => false
  opt :partition, "Set the partition size for parallel provisioning",
   :required => false, :type => :integer, :multi => false
  opt :force, "Force a kill-all command without asking for confirmation",
    :required => false, :type => :flag, :multi => false
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
