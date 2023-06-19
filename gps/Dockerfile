# **************************************************************** #
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
# **************************************************************** #

FROM ubuntu:23.04

ARG _GPS_CONTAINER_HEALTH_SCRIPT

RUN apt-get update -y
RUN apt-get install -y gpsd
RUN apt-get install -y gcc g++ gcc-13 g++-13 make cmake libasound2-dev libudev-dev git libgps-dev
RUN apt-get install -y jq inotify-tools netcat-traditional

WORKDIR / 
RUN git clone https://github.com/iontodirel/gps_util
WORKDIR /gps_util
RUN cmake .
RUN make -j 4

WORKDIR / 
RUN git clone https://github.com/iontodirel/find_devices.git
WORKDIR /find_devices
RUN cmake .
RUN make -j 4

RUN mkdir /gps
WORKDIR /gps
COPY ./start_gpsd.sh start_gpsd.sh
COPY ./health_check.sh ${_GPS_CONTAINER_HEALTH_SCRIPT}
RUN chmod +x start_gpsd.sh
RUN chmod +x ${_GPS_CONTAINER_HEALTH_SCRIPT}

CMD /gps/start_gpsd.sh
