# **************************************************************** #
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
# **************************************************************** #

FROM node:current-bullseye

ENV TZ=America/Los_Angeles

RUN apt-get update && apt-get install -y tzdata
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN mkdir /powershell
WORKDIR /powershell
RUN wget https://github.com/PowerShell/PowerShell/releases/download/v7.2.12/powershell-lts_7.2.12-1.deb_amd64.deb
RUN dpkg -i powershell-lts_7.2.12-1.deb_amd64.deb
RUN apt-get install -f

RUN apt-get update
RUN apt-get install -y default-mysql-client sudo

WORKDIR /webservice
COPY ./webservice/package.json .
COPY ./webservice/app.js .

RUN npm install

WORKDIR /
COPY ./webservice/entrypoint.ps1 entrypoint.ps1
COPY ./common.ps1 common.ps1
COPY ./webservice/healthcheck.ps1 healthcheck.ps1
RUN chmod +x entrypoint.ps1 healthcheck.ps1

CMD ["pwsh", "/entrypoint.ps1"]
