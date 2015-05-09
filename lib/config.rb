require 'digest/sha1'
require 'opennebula'

# All configuration loading and validation should happen here
class PoolConfig

  ##
  # Super type for configuration types.

  class ConfigurationType
  
    ON = ::OpenNebula # Need a shorter constant

    @@instantiation_wait_count = 300 # Try to see if the VM is running this many times before giving up

    ##
    # Keep the raw hash around and then expose it through various methods.

    def initialize(options = {})
      @options = options
      # Dynamically define all the instance readers that are keys of the options hash
      @options.keys.each do |key|
        singleton_class.instance_eval do
          define_method(key.to_sym) do
            item = @options[key]
            if item.nil?
              raise StandardError, "Item is nil: #{key}."
            else
              item
            end
          end
        end
      end
    end

    ##
    # Make sure the right configuration parameters exist and show an error message if they don't.

    def validate
      configuration_items = self.class.class_variable_get(:@@configuration_items)
      missing = configuration_items.reduce([]) do |accumulator, item|
        if @options[item].nil?
          accumulator << item
        end
        accumulator
      end
      if missing.any?
        raise StandardError, "#{self.class} configuration error. Missing configuration parameters: #{missing.join(', ')}."
      end
      extra_items = @options.reject {|k, v| configuration_items.include?(k)}
      if extra_items.any?
        raise StandardError, "Unknown configuration parameters found for configuration class #{self.class}: #{extra_items.keys.join(', ')}."
      end
    end

    ##
    # Wrap an existing configuration so that the +opennebula_state+ method returns the set of IP addresses that were provided on the command line.

    def synthetic(*ip_addresses)
      SyntheticConfigurationType.new(self, ip_addresses)
    end

    ##
    # Try up to 10 times to get the state and then re-raise the exception if there was one.

    def opennebula_state
      counter = 0
      begin
        pool = ON::VirtualMachinePool.new(Utils.client, opennebula_user_id)
        result = pool.info
        if ON.is_error?(result)
          require 'pp'
          pp result
          raise StandardError, "Unable to get pool information. Something is wrong with RPC endpoint."
        end
        vms = pool.to_hash['VM_POOL']['VM']
        everything = vms.nil? ? [] : (Array === vms ? vms : [vms])
        # Filter things down to just this pool
        everything.select {|vm| vm['NAME'].include?(name)}
      rescue Exception => ex
        STDERR.puts ex
        counter += 1
        raise if counter > 20
        sleep 5
        retry
      end
    end

    def hashify_vm_object(vm)
      h = vm.to_hash['VM']
      raise StandardError, "Nil VM." if h.nil?
      h
    end

    ##
    # There is more error handling code than there is actual instantiation code so all of it
    # goes here. Best effort service here with a bunch of timeouts.

    def instantiation_error_handling(vm_objects)
      STDERR.puts "Verifying SSH connections."
      counter = 0
      # reject all failed vms
      run_state_tester = lambda do |vms|
        vms.reject! {|vm| vm.status.include?('fail')}
        vms.all? do |vm|
          vm.info
          vm.status.include?('run') || vm.status.include?('fail')
        end
      end
      while !run_state_tester[vm_objects]
        counter += 1
        if counter > @@instantiation_wait_count
          STDERR.puts "VMs did not transition to running state in the allotted time."
          STDERR.puts "Filtering results and returning running VMs so provisioning process can continue."
          running = []
          vm_objects.each do |vm|
            vm.info
            if vm.status.include?('run')
              running << hashify_vm_object(vm)
            else
              STDERR.puts "VM did not transition to running state: #{vm.to_hash}."
            end
          end
          return running # Just return whatever we can
        end
        sleep 5
      end
      vm_objects.map {|vm| hashify_vm_object(vm)} # Map to hashes and return
    end

    ##
    # Create the required number of VMs and return an array of hashes representing the VMs.
    # We need to wait until we have an IP address for each VM. Re-try 60 times with 1 second timeout for the VMs to be ready.

    def instantiate!(count, vm_name_prefix)
      raise StandardError, "Count must be positive." unless count > 0
      template = ON::Template.new(ON::Template.build_xml(template_id), Utils.client)
      if ON.is_error?(template)
        raise StandardError, "Problem getting template with id: #{template_id}."
      end
      vm_objects = (0...count).map do |i|
        vm_name = vm_name_prefix ? "#{vm_name_prefix}-#{name}" : name
        actual_name = vm_name + '-' + Digest::SHA1.hexdigest(`date`.strip + i.to_s).to_s
        shortened_name = actual_name[0...38] # The entire host name must be less than 63 chars so this plus .itools.one.??? adds up
        vm_id = template.instantiate(shortened_name, false)
        STDOUT.puts "Got VM by id: #{vm_id}."
        vm = Utils.vm_by_id(vm_id)
      end
      # Unfortunate naming but this will return an array of hashes representing the VMs
      instantiation_error_handling(vm_objects)
    end

  end

  ##
  # Wrapper that fakes anything related to getting OpenNebula state to only return the set of IP addresses
  # that was used to instantiate it. This also means that deletion and other kinds of operations will not work.

  class SyntheticConfigurationType < ConfigurationType

    ##
    # The configuration we are wrapping and the list of IP addresses we are faking.

    def initialize(configuration, ip_addresses)
      @configuration = configuration
      @ip_addresses = ip_addresses
    end

  end

  ##
  # Contains configuration parameters for jenkins pools.

  class Jenkins < ConfigurationType

    @@configuration_items = ['name', 'opennebula_user_id', 'type', 'count', 'template_id',
     'provision', 'jenkins', 'jenkins_username', 'jenkins_password',
     'credentials_id', 'private_key_path']

    def initialize(options = {})
      super
      validate
    end

    def provisioner
      Provisioner::JenkinsProvisioner.new(self)
    end

  end

  ##
  # Contains configuration parameters for bamboo pools.

  class Bamboo < ConfigurationType

    @@configuration_items = ['name', 'type', 'opennebula_user_id', 'count', 'template_id',
     'provision', 'bamboo', 'bamboo_username', 'bamboo_password']

    def initialize(options = {})
      super
      validate
    end

    def provisioner
      Provisioner::BambooProvisioner.new(self)
    end

  end

  ##
  # Load a yaml file, parse it, and create the right configuration instance

  def self.load(filepath)
    raw_data = YAML.load(File.read(filepath))
    case (config_type = raw_data['type'])
    when 'jenkins'
      Jenkins.new(raw_data)
    when 'bamboo'
      Bamboo.new(raw_data)
    else
      raise StandardError, "Unknown configuration type: #{config_type}."
    end
  end

end
