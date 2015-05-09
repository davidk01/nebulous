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
      raise StandardError, "Unknown provisioning stage: #{stage}."
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
      raise StandardError, "Path can not be nil" if @path.nil?
      raise StandardError, "Stage number can not be nil" if stage_number.nil?
      raise STandardError, "File does not exist: #{path}." unless File.exist?(path)
    end
  
    def ssh_prefix(ip_address)
      "#{@@ssh_prefix} root@#{ip_address} -t"
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

  end

  ##
  # Upload and unpack a tar file and then run the included 'bootstrap.sh'
  
  class Tar < LocalStage
    
    def initialize(path, stage_number)
      super(path, stage_number)
    end
  
    def commands(ip_address)
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

  end
  
  class Inline < LocalStage
  
    def initialize(command, stage_number)
      raise StandardError, "Command can not be nil." if command.nil?
      @command = command
      @stage_number = stage_number
    end
  
    def commands(ip_address)
      ["#{ssh_prefix(ip_address)} '#{@command} && touch #{@stage_number}-done'"]
    end

  end

end
