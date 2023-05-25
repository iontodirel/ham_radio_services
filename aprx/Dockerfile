FROM ubuntu:23.04

RUN apt-get update -y
RUN apt-get install -y aprx

RUN mkdir /aprx
WORKDIR /aprx
COPY ./aprx.conf aprx.conf
COPY ./start_aprx.sh start_aprx.sh
RUN chmod +x start_aprx.sh

CMD /aprx/start_aprx.sh
