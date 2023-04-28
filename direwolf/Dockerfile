FROM ubuntu:22.04

RUN apt-get update -y
RUN apt-get install -y alsa-tools alsa-utils
RUN apt-get install -y direwolf
RUN apt-get install -y gcc g++ make cmake libasound2-dev git
RUN apt-get install -y jq

RUN git clone https://github.com/iontodirel/find_devices.git
WORKDIR /find_devices
RUN cmake .
RUN make -j 4

RUN mkdir /direwolf
WORKDIR /direwolf
COPY ./config.json config.json
COPY ./start_direwolf.sh start_direwolf.sh
COPY ./direwolf.conf direwolf.conf
RUN chmod +x start_direwolf.sh

CMD /direwolf/start_direwolf.sh
