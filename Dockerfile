FROM ubuntu:18.04

ARG AntMediaServer
ARG MongoDBServer=
ARG MongoDBUsername=
ARG MongoDBPassword=

RUN apt-get update
RUN apt-get install -y libcap2 wget net-tools

ADD ./${AntMediaServer} /home

RUN cd home \
    && pwd \
    && wget https://raw.githubusercontent.com/ant-media/Scripts/master/install_ant-media-server.sh \
    && chmod 755 install_ant-media-server.sh

RUN cd home \
    && pwd \
    && ./install_ant-media-server.sh ${AntMediaServer}


RUN /bin/bash -c 'if [ ! -z "${MongoDBServer}" ]; then \
                    /usr/local/antmedia/change_server_mode.sh cluster ${MongoDBServer} ${MongoDBUsername} ${MongoDBPassword}; \
                 fi'

ENTRYPOINT service antmedia start && /bin/bash
