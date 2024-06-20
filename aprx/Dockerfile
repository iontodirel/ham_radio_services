# **************************************************************** #
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
# **************************************************************** #

FROM ubuntu:23.10

RUN apt-get update -y
RUN apt-get install -y aprx
RUN apt-get install -y gcc gcc-13 g++ g++-13 make cmake git libgps-dev
RUN apt-get install -y netcat-traditional wget

RUN git clone https://github.com/iontodirel/gps_util
WORKDIR /gps_util
RUN cmake .
RUN make -j 4

RUN mkdir /powershell
WORKDIR /powershell
RUN wget https://github.com/PowerShell/PowerShell/releases/download/v7.2.12/powershell-lts_7.2.12-1.deb_amd64.deb
RUN dpkg -i powershell-lts_7.2.12-1.deb_amd64.deb
RUN apt-get install -f

WORKDIR /
COPY ./aprx/entrypoint.ps1 entrypoint.ps1
COPY ./common.ps1 common.ps1
COPY ./aprx/healthcheck.ps1 healthcheck.ps1
COPY ./aprx/printposition.ps1 printposition.ps1
RUN chmod +x entrypoint.ps1 healthcheck.ps1 printposition.ps1

CMD ["pwsh", "/entrypoint.ps1"]
