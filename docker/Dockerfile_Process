# This docker file can be used in kubernetes. 
# It accepts all cluster related parameters at run time. 
# It means it's very easy to add new containers to the cluster 

FROM ubuntu:20.04

ARG AntMediaServer

ARG BranchName=master

#Running update and install makes the builder not to use cache which resolves some updates
RUN apt-get update && apt-get install -y curl wget iproute2 cron logrotate

ADD ./${AntMediaServer} /home

RUN cd home \
    && pwd \
    && wget https://raw.githubusercontent.com/ant-media/Scripts/${BranchName}/install_ant-media-server.sh \
    && chmod 755 install_ant-media-server.sh

RUN cd home \
    && pwd \
    && ./install_ant-media-server.sh -i ${AntMediaServer} -s false


# Options
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

ENTRYPOINT ["/usr/local/antmedia/start.sh"]
