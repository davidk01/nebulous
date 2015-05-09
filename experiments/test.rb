require 'opennebula'
include OpenNebula

creds = File.read('.creds').strip
endpoint = "https://itools-one-head.yojoe.local/RPC2"
client = Client.new(creds, endpoint)
ssh_prefix = ['ssh',
  '-o UserKnownHostsFile=/dev/null',
  '-o StrictHostKeyChecking=no',
  '-o BatchMode=yes',
  '-o ConnectTimeout=10'].join(' ')
scp_prefix = ['scp',
  '-r',
  '-o UserKnownHostsFile=/dev/null',
  '-o StrictHostKeyChecking=no'].join(' ')

# Instantiate a template and get a VM id to create the VM object
template = Template.new(Template.build_xml(3), client)
require 'pry'; binding.pry
vm_id = template.instantiate('davidk-test-1', false)
vm = VirtualMachine.new(VirtualMachine.build_xml(vm_id), client)

# Call '.info' on the VM object until we get to run state
while vm.status != 'runn'
  vm.info
  sleep 1
end

# We are now in the run state and can get the IP address?
vm.info
vm_ip = vm.to_hash['VM']['TEMPLATE']['NIC']['IP']
# Wait until we can make solid ssh connections
while !system("#{ssh_prefix} root@#{vm_ip} -t 'echo uptime'")
  sleep 1
end
require 'pry'; binding.pry
