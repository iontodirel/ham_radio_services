# **************************************************************** #
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
# **************************************************************** #

FROM ubuntu:23.04

ARG _APRX_CONTAINER_HEALTH_SCRIPT

RUN apt-get update -y
RUN apt-get install -y aprx
RUN apt-get install -y gcc gcc-13 g++ g++-13 make cmake git libgps-dev
RUN apt-get install -y jq inotify-tools

RUN git clone https://github.com/iontodirel/gps_util
WORKDIR /gps_util
RUN cmake .
RUN make -j 4

RUN mkdir /aprx
WORKDIR /aprx
COPY ./start_aprx.sh start_aprx.sh
COPY ./fetch_gps.sh fetch_gps.sh
COPY ./health_check.sh ${_APRX_CONTAINER_HEALTH_SCRIPT}
RUN chmod +x start_aprx.sh
RUN chmod +x fetch_gps.sh
RUN chmod +x ${_APRX_CONTAINER_HEALTH_SCRIPT}

CMD /aprx/start_aprx.sh
