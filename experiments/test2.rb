require 'opennebula'
include OpenNebula

require_relative '../lib/spec'
require_relative '../lib/provisioner'
require_relative '../lib/metadata'
require_relative '../lib/utils'

spec = VM.spec do
  name 'davidk-test-1'
  count 2
  template 3
  provision []
end

provisioner = Provisioner.new(spec)
vm_data = provisioner.provision

require 'pry'; binding.pry
