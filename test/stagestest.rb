require 'opennebula'
require_relative '../lib/config'
require_relative '../lib/provisioner'
require_relative '../lib/utils'
require_relative '../lib/stages'
require 'yaml'
require 'minitest/autorun'

class TestStages < Minitest::Test

  def test_script_template_stage
  end

  def test_tar_stage
  end

  def test_basic_script_stage
  end

  def test_file_generation_provisioning
    instances = [Stages::Inline.new('echo hi 1', 1), Stages::Inline.new('echo hi 2', 2),
      Stages::Script.new(File.expand_path(File.dirname __FILE__) + '/harness/script.sh', ['arg1', 'arg2', 'arg3'], 3)]
    stage_collection = Stages::StageCollection.new(*instances)
    stage_collection.generate_files
    generated_files = Dir["tmp/stages/**/*"]
    puts "Generated files: #{generated_files.join(' ')}"
    ['stage-1.sh', 'stage-2.sh', 'stage-3.sh'].each do |file|
      assert(generated_files.any? {|f| f.include?(file)}, "We should have generated #{file}: #{generated_files.join(' ')}.")
    end
    assert(generated_files.any? {|f| f.include?('runner.sh')}, "Runner script must exist.")
  end

  def test_script_stage_as_uploadable
  end

end
