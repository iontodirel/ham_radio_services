# APRS Docker containers

Docker containers for running APRS on ham radio

## Goals

- Easy, fast, and painless deployment of radio services to any new Linux system
  - Zero configuration or system alterations, only needs Docker
  - One click deployment on any Linux system
- Repeatability. Works whether you have 1 or 100 audio devices and serial ports, regardless of system resets, always use the correct audio device and serial ports.
- Reliability. Resilience across restarts, handle crashes and provide 24/7 radio services.


## Limitations

- **Only Linux is currently supported**. This work is targeted at small, cheap and compact Linux embedded devices running radio services 24/7. Windows has limitations sharing hadware to Docker containers. Mac OS support could be added in the future, but running services 24/7 on Mac systems is not considered economical for this to be a priority.
- **No GPIO access**. You can change `compose.yaml` to satisfy your needs and expose GPIO. Support for this out of the box might be added later.

## Running

Follow the instructions in the configuration section first. Run from the root directory::

`docker compose build` \
`docker compose up`

If you want to run the Direwolf container, or one of the containers directly:

`docker build -t direwolf .`
`docker run -p 8000:8000 -p 8001:8001 -t -d --privileged direwolf`

## Troubleshooting

### Build the container without caches

`docker compose build --no-cache`

### Running things into the container

This will expose a serial port and the sound subsystem to the container:

`docker run -it --device /dev/ttyUSB0:/dev/ttyUSB0 --device /dev/snd -tty --entrypoint /bin/sh direwolf`

**NOTE**: change the serial port as appropriate

You could also simply specify the `--privileged` instead of specifying each device to share access to.

## Minimal configuration

Only change settings in the `.env` and `digirig_config.json` files. The `digirig_config.json` file contains the configuration for **find_devices**, for finding the sound card and serial port. Use this file for your Digirig, or create your own. If you use a different configuration file, set the path to it in `FIND_DEVICES_HOST_CONFIG` inside the `.env` file. Read the instructions from find_devices about how to create your own.

Set the `MYCALL` variable to your callsign.

### Additional Settings

The `.env` file contains various defaults and should be only file that needs editing, for any configuration.

The `DIREWOLF_HOST_AGWP_PORT` and `DIREWOLF_HOST_KISS_PORT` variables contains the ports exposed from the container to the host, and what APRS clients will be configured with.

The `direwolf\start_direwolf.sh` contains no hardcoded values, but contains defaults about the directory to log files to, or configuration mode for find_devices.

The `direwolf\direwolf.conf` contains default values for direwolf, but settings like `call sign` and `ports` are automatically substituted in the container, based on the `.env` configuration, during container run, as part of running `start_direwolf.sh`.

## Connecting APRS clients

The APRS containers expose ports `8010` and `8020` for AGWP and KISS use. If you want to change these ports, change the the `DIREWOLF_HOST_AGWP_PORT` and `DIREWOLF_HOST_KISS_PORT` variables in the `.env` file.

### Xastir

Go to Interface - Interface Control, and in the open modal Dialog, then add a new Networked AGWPE port.

![image](https://user-images.githubusercontent.com/30967482/235284143-25f00a58-81ee-4848-a516-8b908d0af504.png)


### YAAC

Go to File - Configure - Export Mode, in the open modal Dialog, then go to Ports, add a new AGWPE port, setting the hostname and port.

![image](https://user-images.githubusercontent.com/30967482/235284000-a2c7125b-9de8-4977-ab19-597b2aa57b35.png)

### PinPoint

Go to Tools - Options, in the open modal Dialog, then go to TNC, set TNC Mode to network KISS mode, set IP address, and set Port to 8020, as this is a KISS TCP connection, and not AGWP.

![image](https://user-images.githubusercontent.com/30967482/235284419-5b581871-4119-466f-bf70-0e30406f9846.png)

## Settings

### Sound card and serial port

### Callsign

## Linux host machine configuration

The Linux system requires minimal configuration, as our container handles everything. The only real requirements are `git` and `Docker`.

### Raspberry Pi 4 with Raspbian 32-bit

Below is an example configuration done to setup the Docker APRS container to run on a fresh install Raspberry Pi.

**1. Setup the system for first time use.**

~~~~
sudo apt-get update
sudo apt-get install git
~~~~

**2. Install Docker**, if on Rasphbian, according to official Docker documentation https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script.

~~~~
curl -fsSL https://get.docker.com -o get-docker.sh`
sudo sh ./get-docker.sh --dry-run`
~~~~

**3. Configure Docker for rootless use** according to official Docker documentation https://docs.docker.com/engine/security/rootless/.

~~~~
sudo sh -eux <<EOF
apt-get install -y uidmap
EOF
dockerd-rootless-setuptool.sh install
~~~~
    
**4. Clone the container repo.**

~~~~
git clone https://github.com/iontodirel/ham_docker_container
cd ham_docker_container
~~~~

**5. Set your callsign in the `.env` file.**

Edit `.env`

If you need to use a different soundcard/serial poort configuration, edit the find_devices configuration file.

**6. Run the container.** *Creating the container will take a few minutes when done for the first time.*

`docker compose up`

### Ubuntu 64-bit on Generic Intel hardware

**1. Setup the system for first time use.**

~~~~
sudo apt-get update
sudo apt-get install git
~~~~

**2. Install Docker**

Follow the official Docker instructions: https://docs.docker.com/engine/install/ubuntu/

**3. Clone the container repo.**

`git clone https://github.com/iontodirel/ham_docker_container` \
`cd ham_docker_container`

**4. Set your callsign in the `.env` file.**

Edit `.env`

If you need to use a different soundcard/serial port configuration, edit the find_devices configuration file.

**6. Run the container.** *Creating the container will take a few minutes when done for the first time.*

`docker compose up`

## Resilience

- The audio soudcard can be connected to any USB port, *depending on your audio configuration*. Follow the instructions from find_devices about creating a find_devices configuration for your devices and circumstances: https://github.com/iontodirel/find_devices
- In case of a USB disconnect, Docker will automatically handle container restart.
- In case of Direwolf crashes, or other Direwolf failures, Docker will automatically handle container restart.
- An internet connection is not required after setting up a system.

## Handling Restarts

There are no needs for any hooks or scripts to run during system initialization. Docker runs automatically after boot by default, and the container policy to auto-restart, auto-restarts the container.
