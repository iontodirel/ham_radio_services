# **************************************************************** #
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
# **************************************************************** #

FROM ubuntu:23.10

RUN apt-get update -y
RUN apt-get install -y alsa-tools alsa-utils
RUN apt-get install -y gcc g++ make cmake libasound2-dev libudev-dev git
RUN apt-get install -y jq mysql-client netcat-traditional wget sox bc curl

# make the "en_US.UTF-8" locale
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

RUN git clone https://github.com/iontodirel/find_devices.git
WORKDIR /find_devices
RUN cmake .
RUN make -j 4

RUN mkdir /powershell
WORKDIR /powershell
RUN wget https://github.com/PowerShell/PowerShell/releases/download/v7.2.12/powershell-lts_7.2.12-1.deb_amd64.deb
RUN dpkg -i powershell-lts_7.2.12-1.deb_amd64.deb
RUN apt-get install -f

WORKDIR /
RUN git clone https://github.com/iontodirel/direwolf-experimental.git
WORKDIR /direwolf-experimental
RUN cmake .
RUN make -j 4
# install direwolf to /usr/local/bin/direwolf
RUN make install

WORKDIR /
COPY ./direwolf/entrypoint.ps1 entrypoint.ps1
COPY ./common.ps1 common.ps1
COPY ./direwolf/healthcheck.ps1 healthcheck.ps1
RUN chmod +x entrypoint.ps1 healthcheck.ps1

CMD ["pwsh", "/entrypoint.ps1"]
