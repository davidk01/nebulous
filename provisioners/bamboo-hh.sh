#!/bin/bash
wget http://ivy/large-third-party/bamboo-agent-install/pt-custom-bamboo-agent-installer-5.7.2.jar

JAVA_ARGS=""
BAMBOO_URL="$1"
server=${BAMBOO_URL}
username="$2"
password="$3"
agent_home="/root/bamboo-agent-home"

/usr/java/jdk1.7.0_latest/bin/java ${JAVA_ARGS} -jar pt-custom-bamboo-agent-installer-5.7.2.jar ${BAMBOO_URL}/agentServer install
touch /root/setenv.sh
echo "test-capability=true" >> ${agent_home}/bin/bamboo-capabilities.properties
echo "ephemeral=true" >> ${agent_home}/bin/bamboo-capabilities.properties
echo "TESTSERVER=true" >> ${agent_home}/bin/bamboo-capabilities.properties

echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDRlOv+AYBThGSnaERV8WjUdK/iKVvuepK56RCMRd1UOdecAsbeF8NWZr8PH/DkyfWJ3xl9XcuD+YvUnf35EEH8n3pL1hsVEEuW6VODdI0Z35njVrk28Spn17G0zsTvVLbF7Ju9P35P7YuvQNZ6KnXYx4FMoCrgOfhRM430tPQZy2PNMPB+dEJfAkUG53WTfQEuEkfpAAFuHynq1qBcuIWia7fKHmCe+3o7NlfCXQfZ3sUDCGth/k2CG5dqEM4sjjLZz2QClT5aKhndtjvFtreU9wim2F1ZBKhUEGO6nHNk+Lqmy+PpxEz+/h+TuuFB0QeQCfUgOyqmMjLdgImCY/sArOyOQ4pztwPj0r+XSPH5zo86vQcFw70aa+/yviwf51DacC/xaBDvJKpJXsPlBEtHlEO0DEAYZsHpSXVscTR2Trgqxjv5qhjaznaBhj7Kc9jF2Ahp24AT60qtrJwFYk0Cig5pHn25JTrfajImt9g7tHb6tkmKzEQnxPCmOn7DhkrSMiTY4lG9qIbx3tIk1V8ZQaw5jwprWo/NrFdAoKxM9i8T3TFWcCiaVCWKaX7TOYEYpkpeDUXiRRqHoUVf3lA9xg6WH5xmMvGW2iHqz77MNPE5lrlCmEQd9hJGAFO7jmTkRJM+LgJkic8WZwMr8lIrd3/anavWrueoem0AJnEasw== davidk@davidk-mbp" >> /root/.ssh/authorized_keys

# Plop down the self-killer script
echo "" > /usr/local/self-killer
echo "if !ENV['bamboo_capability_ephemeral']" >> /usr/local/self-killer
echo "if \`cat ${agent_home}/bin/bamboo-capabilities.properties\`[\"ephemeral\"].nil?" >> /usr/local/self-killer
echo "raise StandardError, \"Can not disable non-ephemeral agent\"" >> /usr/local/self-killer
echo "end" >> /usr/local/self-killer
echo "end" >> /usr/local/self-killer
echo "agent_id = ENV['bamboo_agentId']" >> /usr/local/self-killer
echo "if agent_id.nil?" >> /usr/local/self-killer
echo "agent_id = \`cat ${agent_home}/bamboo-agent.cfg.xml | grep '<id>'\`.strip.match(/(\d+)/)[1]" >> /usr/local/self-killer
echo "end" >> /usr/local/self-killer
echo "\`curl -b bamboo-cookies.txt -c bamboo-cookies.txt -s -u '${username}':'${password}' '${server}/admin/agent/disableAgent.action?agentId=#{agent_id}'\`" >> /usr/local/self-killer

# Start the agent
export PATH=/usr/java/jdk1.7.0_latest/bin/:$PATH
${agent_home}/bin/bamboo-agent.sh restart
