FROM ubuntu:23.04

RUN apt-get update -y
RUN apt-get install -y gpsd
RUN apt-get install -y gcc g++ make cmake libasound2-dev libudev-dev git
RUN apt-get install -y jq

RUN git clone https://github.com/iontodirel/find_devices.git
WORKDIR /find_devices
RUN cmake .
RUN make -j 4

RUN mkdir /gps
WORKDIR /gps
COPY ./start_gpsd.sh start_gpsd.sh
RUN chmod +x start_gpsd.sh

CMD /gps/start_gpsd.sh
