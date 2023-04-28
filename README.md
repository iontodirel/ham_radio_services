# APRS Docker containers

Docker containers for running APRS on ham radio

## Containers

### Direwolf container

Run from the direwolf directory.

To build the container: `docker build -t direwolf .`

To run the container: `docker container run --env-file ./../.env -p 8010:8000 -p 8020:8001 -t -d --device /dev/snd direwolf`

To shell into the container: `docker container run --env-file ./../.env -p 8010:8000 -p 8020:8001 --device /dev/snd --interactive --tty --entrypoint /bin/sh direwolf`

## Running

Run from the root directory.

To build and run the container

`docker compose build` \
`docker compose up` 

## Settings

The `.env` file contains various defaults and should be only file that needs editing for any configuration. At minimum, set the `MYCALL` variable to your callsign.

The `DIREWOLF_HOST_AGWP_PORT` and `DIREWOLF_HOST_KISS_PORT` variables contains the ports exposed from the container to the host, and what APRS clients will be configured with.

If you have more than one audio device type, capable of both playback and rendering, use `AUDIO_USB_NAME` and `AUDIO_USB_DESC` to select it. Currently, multiple audio devices of the same type are not supported, ex: Two Signalink on the same system. This is because while we can detect them, we cannot disambiguate which one to use based on name or description, as they are all based on Texas Instruments CODECs, with the same USB descriptors and same name and description. Future work might address this issue by selecting devices based on USB port used.

The `direwolf\start_direwolf.sh` contains no hardcoded values, but contains defaults about directory to log files to, or configuration type for findind the Alsa devices.

The `direwolf\direwolf.conf` contains default values for direwolf, but settings like call sign and ports are substituted based on the `.env` configuration, during container run, as part of running `start_direwolf.sh`.

## Linux host machine configuration

Follow the Settings section for the initial configuration. 

The Linux system requires minimal configuration, as our container handles it. The only real requirements are `git` and `Docker`.

### Raspberry Pi 4 with Rasphbian

Below is an example configuration done to setup the Docker APRS container to run on a fresh install Raspberry Pi.

Setup the system for first time use. Install minimal dependencies.

`sudo apt-get update`\
`sudo apt-get install git`

Install Docker, if on Rasphbian, according to official Docker documentation https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script.

`curl -fsSL https://get.docker.com -o get-docker.sh`\
`sudo sh ./get-docker.sh --dry-run`

Configure Docker for rootless use according to official Docker documentation https://docs.docker.com/engine/security/rootless/.

`sudo sh -eux <<EOF` \
`apt-get install -y uidmap` \
`EOF`\
`dockerd-rootless-setuptool.sh install`
                   
Clone the container repo and run Docker.

`git clone https://github.com/iontodirel/ham_docker_container`\
`cd ham_docker_container`\

Set your callsign in the `.env` file, before running Docker. Creating the container will take a few minutes for the first time.

`docker compose up`

## Resilience

- The audio soudcard can be connected to any USB port.
- In case of a USB disconnect, Docker will automatically handle container restart.
- In case of Direwolf crashes, or other failures Docker will automatically handle container restart.

## Handling Restarts

Use this to start the Docker container after a system reboot

TBD

## Connecting APRS clients

The APRS containers expose ports `8010` and `8020` for AGWP and KISS use.
