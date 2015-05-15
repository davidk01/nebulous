require 'opennebula'
require_relative '../lib/config'
require_relative '../lib/provisioner'
require_relative '../lib/utils'
require_relative '../lib/stages'
require 'yaml'
require 'minitest/autorun'

class TestStages < Minitest::Test

  def test_file_generation_provisioning
    instances = [Stages::Inline.new('echo hi 1', 1), Stages::Inline.new('echo hi 2', 2),
      Stages::Script.new(File.expand_path(File.dirname __FILE__) + '/harness/script.sh', ['arg1', 'arg2', 'arg3'], 3),
      Stages::Tar.new(File.expand_path(File.dirname __FILE__) + '/harness/test.tar', ['arg1', 'arg2', 'arg3'], 4)]
    stage_collection = Stages::StageCollection.new(*instances)
    stage_collection.generate_files
    generated_files = Dir["tmp/stages/**/*"]
    puts "Generated files: #{generated_files.join(' ')}"
    ['stage-1.sh', 'stage-2.sh', 'stage-3.sh', 'stage-4.tar'].each do |file|
      assert(generated_files.any? {|f| f.include?(file)}, "We should have generated #{file}: #{generated_files.join(' ')}.")
    end
    assert(generated_files.any? {|f| f.include?('runner.sh')}, "Runner script must exist.")
  end

end
