require_relative './errors'

module Stages

  def self.from_config(stage, stage_number)
    case stage['type']
    when 'inline'
      Inline.new(stage['command'], stage_number)
    when 'script'
      Script.new(stage['path'], stage['arguments'], stage_number)
    when 'template'
      ScriptTemplate.new(stage['path'], stage['arguments'], stage_number)
    when 'directory'
      Directory.new(stage['path'], stage['arguments'], stage_number)
    when 'tar'
      Tar.new(stage['path'], stage['arguments'], stage_number)
    else
      raise UnknownProvisioningStageError, "Unknown provisioning stage: #{stage}."
    end
  end

  ##
  # Contains a bunch of stages so that there is some kind of generic interface from the provisioners perspective

  class StageCollection

    @@dir_prefix = "tmp/stages"
    @@scp_prefix = ['scp', '-o UserKnownHostsFile=/dev/null', '-o StrictHostKeyChecking=no'].join(' ')
    @@ssh_prefix = ['ssh', '-o UserKnownHostsFile=/dev/null', '-o StrictHostKeyChecking=no', '-o BatchMode=yes', '-o ConnectTimeout=10'].join(' ')
    @@runner_script = "runner.sh"

    def initialize(*stages)
      @stages = stages
    end

    ##
    # Assuming for now we make a tmp directory wherever we are and then plopping down files in that directory.

    def generate_files
      # Clear out all the old stuff, re-make the directory, and generate the files
      `rm -rf #{@@dir_prefix}`
      `mkdir -p #{@@dir_prefix}`
      @stages.each do |stage|
        stage.generate_file({:prefix => @@dir_prefix})
      end
      STDOUT.puts "Generating runner script."
      open(File.join(@@dir_prefix, @@runner_script), 'w') do |f|
        @stages.each do |stage|
          f.puts stage.runner_command
        end
      end
      # At this point whatever is in @@dir_prefix should have all the necessary files that we can scp them over to the host
    end

    ##
    # Copy the files to the host

    def scp_files(ip)
      if Dir[File.join(@@dir_prefix, '*')].empty?
        raise ProvisioningDirectoryError, "Could not find any files to copy over in dir #{@@dir_prefix}."
      end
      STDOUT.puts "Copying files to #{ip} from #{@@dir_prefix}."
      `#{@@scp_prefix} -r #{@@dir_prefix}/* root@#{ip}:`
    end

    ##
    # Once the files are uploaded go to the remote system and execute the runner script.

    def execute_remote_stages(ip)
      command = "#{@@ssh_prefix} root@#{ip} -t 'bash runner.sh'"
      STDOUT.puts "Running command: #{command}."
      `#{command}`
    end

  end

  ##
  # Provisioners that look to the local file system for the various provisioning pieces as opposed
  # to looking remotely like http, git, etc.
  
  class LocalStage

    ## These are the options commmon to all SSH commands
    @@ssh_prefix = ['ssh', '-o UserKnownHostsFile=/dev/null',
     '-o StrictHostKeyChecking=no', '-o BatchMode=yes', '-o ConnectTimeout=10'].join(' ')

    ## These are the options common to all SCP commands
    @@scp_prefix = ['scp', '-o UserKnownHostsFile=/dev/null', '-o StrictHostKeyChecking=no'].join(' ')
  
    def initialize(path, stage_number)
      @path = path
      @stage_number = stage_number
      raise PathNilError, "Path can not be nil" if @path.nil?
      raise StageNumberNilError, "Stage number can not be nil" if stage_number.nil?
      raise FilePathError, "File does not exist: #{path}." unless File.exist?(path)
    end
  
    def ssh_prefix(ip_address)
      "#{@@ssh_prefix} root@#{ip_address} -t"
    end

    def generate_file(opts = {})
      prefix = opts[:prefix]
      if prefix.nil?
        raise FileLocationError, "Need a file prefix for writing output of stage."
      end
      if Dir[File.join(prefix, '*')].any? {|name| name.include?(@stage_number.to_s)}
        raise StageFileExistsError, "File for stage already exists: stage number = #{@stage_number}."
      end
    end

    def runner_command
      raise StandardError, "Must define in subclass"
    end

  end
  
  ##
  # The resources are pulled from a remote location instead of the local filesystem.
  
  class RemoteStage
    
    def initialize
      raise StandardError
    end
  
    def commands(ip_address)
    end

    def generate_file(opts = {})
    end

    def runner_command
    end

  end
  
  ##
  # Take an ERB template and generate a bash script from it.

  class ScriptTemplate < LocalStage

    def initialize(path, arguments, stage_number)
      @arguments = arguments
      super(path, stage_number)
    end

    ##
    # Evaluate the template then write it to a file and then generate the commands
    # for uploading it to the server and executing it just like a regular script type command.

    def commands(ip_address)
    end

    def generate_file(opts = {})
    end

    def runner_command
    end

  end

  ##
  # Upload and unpack a tar file and then run the included 'bootstrap.sh'
  
  class Tar < LocalStage
    
    def initialize(path, stage_number)
      super(path, stage_number)
    end
  
    def commands(ip_address)
    end

    def generate_file(opts = {})
    end

    def runner_command
    end
  end
  
  ##
  # Upload and run a shell script.
  
  class Script < LocalStage
  
    def initialize(path, arguments, stage_number)
      @arguments = arguments || []
      super(path, stage_number)
    end
  
    ##
    # SCP stuff over, chmod +x, and run it.

    def commands(ip_address)
      script_arguments = @arguments.map {|arg| "\"#{arg}\""}.join(' ')
      ["#{@@scp_prefix} '#{@path}' root@#{ip_address}:stage-#{@stage_number}.sh",
       "#{ssh_prefix(ip_address)} 'chmod +x stage-#{@stage_number}.sh'",
       "#{ssh_prefix(ip_address)} './stage-#{@stage_number}.sh #{script_arguments} && touch #{@stage_number}-done'"]
    end

    ##
    # Just copy the file to target directory with new name.

    def generate_file(opts = {})
      super(opts)
      prefix = opts[:prefix]
      STDOUT.puts "Generating file for script command."
      target = File.join(prefix, "stage-#{@stage_number}.sh")
      `cp #{@path} #{target}`
    end

    ##
    # Execute the script with the arguments. Escaping can be a problem here.

    def runner_command
      script_arguments = @arguments.map {|arg| "\"#{arg}\""}.join(' ')
      "bash ./stage-#{@stage_number}.sh #{script_arguments}"
    end

  end
  
  ##
  # Upload an entire directory and run the included 'bootstrap.sh'
  
  class Directory < LocalStage
  
    def initialize(path, arguments, stage_number)
      @arguments = arguments || []
      super(path, stage_number)
    end
  
    def commands(ip_address)
      stage_dir = "stage-#{@stage_number}"
      script_arguments = @arguments.map {|arg| "\"#{arg}\""}.join(' ')
      ["#{@@scp_prefix} -r '#{@path}' root@#{ip_address}:#{stage_dir}",
       "#{ssh_prefix(ip_address)} 'pushd #{stage_dir} && bash setup.sh #{script_arguments} && popd && touch #{@stage_number}-done'"]
    end

    def generate_file(opts = {})
      super(opts)
    end

    def runner_command
    end

  end
  
  class Inline < LocalStage
  
    def initialize(command, stage_number)
      raise ArgumentError, "Command can not be nil." if command.nil?
      @command = command
      @stage_number = stage_number
    end
  
    def commands(ip_address)
      ["#{ssh_prefix(ip_address)} '#{@command} && touch #{@stage_number}-done'"]
    end

    ##
    # Plop down a file so that it can be uploaded to the host to be executed.

    def generate_file(opts = {})
      super(opts)
      prefix = opts[:prefix]
      STDOUT.puts "Generating file for inline command."
      File.open(File.join(prefix, "stage-#{@stage_number}.sh"), 'w') do |f| 
        f.puts @command
        f.puts "if [[ $? ]]; then touch stage-#{@stage_number}-done; fi"
      end
    end

    def runner_command
      "bash ./stage-#{@stage_number}.sh"
    end

  end

end
