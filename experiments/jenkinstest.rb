require 'json'
require 'net/http'
require 'openssl'

def save_command(params)
{'_.name' => 'test agent',
	'_.nodeDescription' => 'agent description',
	'_.numExecutors' => '1',
	'_.remoteFS' => '/var/jenkins',
	'_.labelString' => 'BNCLHOST',
	'mode' => 'NORMAL',
	'stapler-class' => 'hudson.plugins.sshslaves.SSHLauncher',
	'kind' => 'hudson.plugins.sshslaves.SSHLauncher',
	'$class' => 'hudson.plugins.sshslaves.SSHLauncher',
	'_.host' => params[:slave_host],
	'_.credentialsId' => '254037e7-c4a1-46db-9069-f9289b99e6e2',
	'_.port' => '22',
	'_.javaPath' => '',
	'_.jvmOptions' => '',
	'_.prefixStartSlaveCmd' => '',
	'_.suffixStartSlaveCmd' => '',
	'launchTimeoutSeconds' => '',
	'maxNumRetries' => '0',
	'retryWaitTime' => '0',
	'stapler-class' => 'hudson.slaves.JNLPLauncher',
	'kind' => 'hudson.slaves.JNLPLauncher',
	'$class' => 'udson.slaves.JNLPLauncher',
	'_.tunnel' => '',
	'_.vmargs' => '',
	'stapler-class' => 'hudson.slaves.CommandLauncher',
	'kind' => 'hudson.slaves.CommandLauncher',
	'$class' => 'hudson.slaves.CommandLauncher',
	'_.command' => '',
	'stapler-class' => 'udson.os.windows.ManagedWindowsServiceLauncher',
	'kind' => 'hudson.os.windows.ManagedWindowsServiceLauncher',
	'$class' => 'hudson.os.windows.ManagedWindowsServiceLauncher',
	'_.userName' => '',
	'_.password' => '',
	'_.host' => '',
	'stapler-class' => 'hudson.os.windows.ManagedWindowsServiceAccount$LocalSystem',
	'$class' => 'hudson.os.windows.ManagedWindowsServiceAccount$LocalSystem',
	'stapler-class' => 'hudson.os.windows.ManagedWindowsServiceAccount$AnotherUser',
	'$class' => 'hudson.os.windows.ManagedWindowsServiceAccount$AnotherUser',
	'stapler-class' => 'hudson.os.windows.ManagedWindowsServiceAccount$Administrator',
	'$class' => 'hudson.os.windows.ManagedWindowsServiceAccount$Administrator',
	'_.javaPath' => '',
	'_.vmargs' => '',
	'stapler-class' => 'udson.slaves.RetentionStrategy$Always',
	'kind' => 'hudson.slaves.RetentionStrategy$Always',
	'$class' => 'hudson.slaves.RetentionStrategy$Always',
	'stapler-class' => 'hudson.slaves.SimpleScheduledRetentionStrategy',
	'kind' => 'hudson.slaves.SimpleScheduledRetentionStrategy',
	'$class' => 'hudson.slaves.SimpleScheduledRetentionStrategy',
	'retentionStrategy.startTimeSpec' => '',
	'retentionStrategy.upTimeMins' => '',
	'retentionStrategy.keepUpWhenActive' => 'on',
	'stapler-class' => 'udson.slaves.RetentionStrategy$Demand',
	'kind' => 'hudson.slaves.RetentionStrategy$Demand',
	'$class' => 'hudson.slaves.RetentionStrategy$Demand',
	'retentionStrategy.inDemandDelay' => '',
	'retentionStrategy.idleDelay' => '',
	'stapler-class-bag' => 'true',
	'json' => {"name" =>  params[:name], "nodeDescription" => "agent description", "numExecutors" =>  "1", "remoteFS" =>  "/var/jenkins", "labelString" =>  params[:label], "mode" =>  "NORMAL", "" => ["hudson.plugins.sshslaves.SSHLauncher", "hudson.slaves.RetentionStrategy$Always"], "launcher" =>  {"stapler-class" =>  "hudson.plugins.sshslaves.SSHLauncher", "kind" =>  "hudson.plugins.sshslaves.SSHLauncher", "$class" =>  "hudson.plugins.sshslaves.SSHLauncher", "host" =>  params[:slave_host], "credentialsId" =>  "254037e7-c4a1-46db-9069-f9289b99e6e2", "port" =>  "22", "javaPath" =>  "", "jvmOptions" =>  "", "prefixStartSlaveCmd" =>  "", "suffixStartSlaveCmd" =>  "", "launchTimeoutSeconds" =>  "", "maxNumRetries" =>  "0", "retryWaitTime" =>  "0"}, "retentionStrategy" =>  {"stapler-class" =>  "hudson.slaves.RetentionStrategy$Always", "kind" =>  "hudson.slaves.RetentionStrategy$Always", "$class" =>  "hudson.slaves.RetentionStrategy$Always"}, "nodeProperties" =>  {"stapler-class-bag" => "true"}}.to_json,
	'Submit' => 'Save'}
	end

def post_request(params)
	post_params = {
		'name' => params[:name],
		'type' => 'hudson.slaves.DumbSlave$DescriptorImpl',
		'json' => {
			'name' => params[:name],
			'numExecutors' => 1,
			'remoteFS' => '/var/jenkins',
			'nodeDescription' => 'agent description',
			'labelString' => params[:label],
			'mode' => 'NORMAL',
			'type' => 'hudson.slaves.DumbSlave$DescriptorImpl',
			'retentionStrategy' => {
				'stapler-class' => 'hudson.slaves.RetentionStrategy$Always'
			},
			'nodeProperties' => {
				'stapler-class-bag' => true
			},
			'launcher' => {
				'stapler-class' => 'hudson.plugins.sshslaves.SSHLauncher',
				'host' => params[:slave_host],
				'port' => 22,
				'username' => params[:slave_user],
				'privatekey' => params[:private_key_file],
				'credentialsId' => params[:credentials_id]
			}
		}.to_json
	}
end

# 'Create the node'
params = {:name => 'test agent', :slave_host => '10.160.36.56', :slave_user => 'root',
        :private_key_file => '/Users/davidk/.ssh/id_rsa', :label => 'BNCLHOST',
        :credentials_id => '254037e7-c4a1-46db-9069-f9289b99e6e2'}
request = Net::HTTP::Post.new('/computer/doCreateItem')
request.set_form_data(post_request(params))
request.basic_auth @username, @password if @username

# set ssl if we are using https
http = Net::HTTP.new('127.0.0.1', 8080)
if @ssl
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
end

response = http.request(request)
require 'pry'; binding.pry
sleep 1

# Save the node
agent_name = params[:name].gsub(/ /, '%20')
save_request = Net::HTTP::Post.new("/computer/#{agent_name}/configSubmit")
save_request.set_form_data(save_command(params))
save_response = http.request(save_request)
sleep 1

# Launch the node
launch_request = Net::HTTP::Post.new('/computer/#{agent_name}/launchSlaveAgent')
launch_request.set_form_data({'json' => {}.to_json, 'Submit' => 'Launch slave agent'})
launch_response = http.request(launch_request)
require 'pry'; binding.pry
