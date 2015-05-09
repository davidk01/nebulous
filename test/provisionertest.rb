require 'opennebula'
require_relative '../lib/config'
require_relative '../lib/provisioner'
require_relative '../lib/utils'
require 'yaml'
require 'minitest/autorun'

class TestProvisioner < Minitest::Test

  def test_bamboo_forking
    config = PoolConfig.load('./harness/bamboo.yaml')
    provisioner = config.provisioner
    config.stub :opennebula_state, [] do
      assert(provisioner.delta == 100, "Pool delta is 100.")
      forked_provisioners = (1..100).each_slice(20).map {|slice| provisioner.forked_provisioner(slice.length)}
      assert(forked_provisioners.length == 5, "Delta should be 100 so we must have 5 provisioners.")
      forked_provisioners.each do |p|
        assert(p.delta == 20, "Each provisioner must have a delta of 20.")
      end
    end
  end

  def test_bamboo_partitioning
    config = PoolConfig.load('./harness/bamboo.yaml')
    provisioner = config.provisioner
    config.stub :opennebula_state, [] do
      assert(provisioner.delta == 100, "Pool delta is 100.")
      forked_provisioners = provisioner.partition(20)
      assert(forked_provisioners.length == 5, "We must have 5 forked provisioners.")
      forked_provisioners.each do |p|
        assert(p.delta == 20, "Each provisioner must have a delta of 20.")
      end
    end
  end

end
