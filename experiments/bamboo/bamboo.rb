##
# The pipeline of what is supposed to happen:
# 1. Find all running jobs and extract the underlying agents
# 2. Request those agents to stop
# 3. Poll until they are stopped
# 4. Bring up new agents to replace them
# The above steps are not necessarily synchronous and it is unclear how to make
# the process robust.

# Bamboo REST endpoint style is server/rest/api/latest/endpoint?os_authType=basic&query

class Bamboo

  def initialize(username, password, server)
    @username = username
    @password = password
    @server = server
    # Make sure server parameter is of the form 'https://server/'
    @server += '/' unless [47, '/'].include? @server[-1]
    @server = 'https://' + @server unless @server[0..7] == 'https://'
  end

end

##
# Just find the relevant data on all the running jobs in a format the rest of the pipeline expects.
# There is no API endpoint so we are going to have to scrape it.

class RunningJobs < Bamboo

  ##
  # Convenient container for the pieces of data we are interested in.

  class JobData < Struct.new(:job_endpoint, :agent_endpoint)
  end

  ##
  # Username, password, server.

  def initialize(username, password, server)
    super
  end

  ##
  # Go to agent page and scrape the active job data.

  def running_jobs
    raw_data = `curl -s -u '#{@username}':'#{@password}' #{@server}admin/agent/configureAgents!default.action | grep -A6 'agentBuilding'`.strip
    # Filter out any empty strings because for some reason the first element is the empty string.
    raw_data.split('<tr class="agentBuilding">').reject(&:empty?).map do |job_data|
      # Don't need the leading forward slash so that's why it is not in capture group
      agent, job = *job_data.scan(/href="\/(.+)"/).flatten
      JobData.new(@server + job, @server + agent)
    end
  end

end

##
# Once we have the active jobs and agent URL we need to go to the agent page
# and request the agent to stop. The problem is there is an indeterminate amount of time
# between requesting the stop and when the agent actually stops.

class Requester

  ##
  # Same as for +RunningJobs+.

  def initialize(username, password, server)
    super
  end

  ##
  # Take the job and agent endpoint data and request the agent to stop.

  def request_agent_stop(*job_data)
  end

end
