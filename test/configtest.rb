require 'opennebula'
require_relative '../lib/config'
require_relative '../lib/provisioner'
require_relative '../lib/utils'
require 'yaml'
require 'minitest/autorun'

class TestConfig < Minitest::Test

  @@valid_jenkins_config = {
      'type' => 'jenkins', 'name' => '#?nonsense', 'count' => 10, 'template_id' => 3,
      'provision' => [], 'jenkins' => 'http://some.server',
      'jenkins_username' => 'someuser', 'jenkins_password' => 'somepassword',
      'private_key_path' => '/some/file/path', 'credentials_id' => 'uuid',
      'opennebula_user_id' => 7
  }

  @@valid_bamboo_config = {
     'type' => 'bamboo', 'name' => '#?nonsense', 'count' => 20, 'template_id' => 3,
     'provision' => [], 'bamboo' => 'http://some.server',
     'bamboo_username' => 'someuser', 'bamboo_password' => 'somepassword',
     'opennebula_user_id' => 7
  }

  def test_empty_jenkins_config
    assert_raises(StandardError, "Empty config throws an error") { PoolConfig::Jenkins.new({}) }
  end

  def test_empty_bamboo_config
    assert_raises(StandardError, "Empty config throws an error") { PoolConfig::Bamboo.new({}) }
  end

  def test_nonempty_jenkins_config
    assert(PoolConfig::Jenkins.new(@@valid_jenkins_config), "Valid config creates new instance: Jenkins")
  end

  def test_nonempty_bamboo_config
    assert(PoolConfig::Bamboo.new(@@valid_bamboo_config), "Valid config creates new instance: Bamboo")
  end

  def test_extra_jenkins_params
    assert_raises(StandardError, "Extra arguments are an error") { PoolConfig::Jenkins.new(@@valid_jenkins_config.merge({'extra' => true})) }
  end

  def test_extra_bamboo_params
    assert_raises(StandardError, "Extra arguments are an error") { PoolConfig::Bamboo.new(@@valid_bamboo_config.merge({'extra' => true})) }
  end

  def test_loading_jenkins_yaml
    assert(PoolConfig::Jenkins === PoolConfig.load('./harness/jenkins.yaml'), "Jenkins configuration type creates Jenkins configuration instance")
  end

  def test_loading_bamboo_yaml
    assert(PoolConfig::Bamboo === PoolConfig.load('./harness/bamboo.yaml'), "Bamboo configuration type creates Bamboo configuration instance")
  end

  def test_loading_unknown_yaml
    assert_raises(StandardError, "Loading unknown configuration type raises an error") { PoolConfig.load('./harness/unknown.yaml') }
  end

  def test_getting_jenkins_provisioner
    assert(Provisioner::JenkinsProvisioner === PoolConfig.load('./harness/jenkins.yaml').provisioner, "Should load jenkins provisioner")
  end

  def test_getting_bamboo_provisioner
    assert(Provisioner::BambooProvisioner === PoolConfig.load('./harness/bamboo.yaml').provisioner, "Should load bamboo provisioner")
  end

  def test_opennebula_state_jenkins
    config = PoolConfig.load('./harness/jenkins.yaml')
    vms = config.opennebula_state
    assert(vms.empty?, "There should be no VMs for the jenkins harness configuration")
  end

  def test_opennebula_state_bamboo
    config = PoolConfig.load('./harness/bamboo.yaml')
    vms = config.opennebula_state
    assert(vms.empty?, "There should be no VMs for the bamboo harness configuration")
  end

end
