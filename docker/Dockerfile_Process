# This docker file can be used in kubernetes. 
# It accepts all cluster related parameters at run time. 
# It means it's very easy to add new containers to the cluster 

FROM ubuntu:22.04

ARG AntMediaServer
ARG LicenseKey

ARG BranchName=master

#Running update and install makes the builder not to use cache which resolves some updates
RUN apt-get update && apt-get install -y curl wget iproute2 cron logrotate

ADD ./${AntMediaServer} /home

RUN cd home \
    && pwd \
    && wget https://raw.githubusercontent.com/ant-media/Scripts/${BranchName}/install_ant-media-server.sh \
    && chmod 755 install_ant-media-server.sh

RUN cd /home \
    && pwd \
    && if [ -n "$AntMediaServer" ]; then \
           ./install_ant-media-server.sh -i ${AntMediaServer} -s false; \
       elif [ -n "$LicenseKey" ]; then \
           ./install_ant-media-server.sh -l ${LicenseKey} -s false; \
       else \
           echo "Both AntMediaServer and LicenseKey arguments are not provided. Aborting the build process."; \
           exit 1; \
       fi

#
# Options:
#
# -g: Use global(Public) IP in network communication. Its value can be true or false. Default value is false.
#
# -s: Use Public IP as server name. Its value can be true or false. Default value is false.
#
# -r: Replace candidate address with server name. Its value can be true or false. Default value is false
#
# -m: Server mode. It can be standalone or cluster. If cluster mode is specified then mongodb host, username and password should also be provided.
#     There is no default value for mode
#
# -h: MongoDB or Redist host. It's either IP address or full connection string such as mongodb://[username:password@]host1[:port1] or mongodb+srv://[username:password@]host1[:port1] or redis://[username:password@]host1[:port1] or redis yaml configuration
#
# -u: MongoDB username: Deprecated. Just give the username in the connection string with -h parameter
#
# -p: MongoDB password: Deprecated. Just give the password in the connection string with -h parameter
#
# -l: Licence Key

# -a: TURN/STUN Server URL for the server side. It should start with "turn:" or "stun:" such as stun:stun.l.google.com:19302 or turn:ovh36.antmedia.io
#     this url is not visible to frontend users just for server side.
#
# -n: TURN Server Usermame: Provide the TURN server username to get relay candidates.
#
# -w: TURN Server Password: Provide the TURN server password to get relay candidates.
#
# -k: Kafka Address: Provide the Kafka URL address to collect data. (It must contain the port number. Example: localhost:9092)
#
# -j: JVM Memory Options(-Xms1g -Xmx4g): Set the Java heap size. Default value is "-Xms1g". Example usage: ./start.sh -j "-Xms1g -Xmx4g"
#
# -c: CPU Limit: Set the CPU limit percentage that server does not exceed. Default value is 75. 
#       If CPU is more than this value, server reports highResourceUsage and does not allow publish or play.
#       Example usage: ./start.sh -c 60
#
# -e: Memory Limit: Set the Memory Limit percentage that server does not exceed. Default value is 75
#       If Memory usage is more than this value, server reports highResourceUsage and does not allow publish or play
#       Example usage: ./start.sh -e 60


ENTRYPOINT ["/usr/local/antmedia/start.sh"]
