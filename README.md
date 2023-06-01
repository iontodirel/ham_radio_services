# APRS Docker containers

Docker containers for running APRS on ham radio.

These containers are fully functional and finished, but they primarely serve as templates that can easily be modified and repurposed into different applications for APRS and ham radio use. The goal is to have configurability via minimal code changes, no scripting, and rather than supporting all possible use cases, support a set of use case while providing all flexibility to adapt via small code changes.

## Goals

- Easily modifiable and repurposable containers, scripts and code. Easy to repurpose via small code edits
- Easy, fast, and painless deployment of radio services to any new Linux system
  - Zero configuration or system alterations, only needs Docker
  - One click deployment on any Linux system
  - Only use Docker with no host scripting
- Repeatability on any (Linux) host. Works whether you have 1 or 100 audio devices and serial ports, regardless of system resets, always use the correct audio device and serial ports. *Based on work I have done for find_devices https://github.com/iontodirel/find_devices*.
- Reliability. Resilience across restarts, with health checks, handle crashes to provide *24/7* radio services.
- Minimal internal scripting

## Limitations

- **Only Linux is currently supported**. This work is targeted at small, cheap and compact Linux embedded devices, running radio services 24/7. Windows has limitations sharing hadware to Docker containers. Mac OS systems run Docker in a VM and have the same system limitations as Windows.
- **The --privileged mode**. Unfortunately compose does not have hooks for host scripting, which means we need to run find_devices in the containers, and the containers (find_devices) need hardware access. We could simply run this in the host and only expose to the containers the devices required more granularly, but then we loose the usefulness and convinience of Docker Compose.

## Configuration

These containers are not an E2E application, they are not meant to be taken as is without modifications. They are written for maximum hackability with minimal changes.

If you don't need GPS, and repeater capabilities, or don't have the GPS hardware, simply comment these services in the `compose.yaml` file that you don't need. If you need another direwolf container to listen only, simply add it in the compose file. 

If you don't use a Digirig, simple write another configuration for find_devices. find_devices should support any sound card device.

## Running

Follow the instructions in the configuration section first. Run from the root directory::

`docker compose build` \
`docker compose up`

If you want to run the Direwolf container, or one of the containers directly:

`docker build -t direwolf .` \
`docker run -p 8000:8000 -p 8001:8001 -t -d --privileged direwolf`

## Troubleshooting

### Build the container without caches

`docker compose build --no-cache`

### Running things into the container

This will expose a serial port and the sound subsystem to the Docker container:

`docker run -it --device /dev/ttyUSB0:/dev/ttyUSB0 --device /dev/snd --tty --entrypoint /bin/sh direwolf`

**NOTE**: change the serial port as appropriate. You could also simply specify the `--privileged` instead of specifying each device to share access to.

This will build the gps container, and then run it with hardware access, and with a prompt in the container:

`docker build -t gps .`
`docker run -it --privileged --tty --entrypoint /bin/sh gps`

## Minimal configuration

Only change settings in the `.env` and `digirig_config.json` files. The `digirig_config.json` file contains the configuration for **find_devices**, for finding the sound card and serial port. Use this file for your Digirig, or create your own. If you use a different configuration file, set the path to it in `FIND_DEVICES_HOST_CONFIG` inside the `.env` file. Read the instructions from find_devices about how to create your own.

Set the `MYCALL` variable to your callsign.

### Additional Settings

The `.env` file contains various defaults and should be only file that needs editing, for any configuration.

The `DIREWOLF_HOST_AGWP_PORT` and `DIREWOLF_HOST_KISS_PORT` variables contains the ports exposed from the container to the host, and what APRS clients will be configured with.

The `direwolf\start_direwolf.sh` contains no hardcoded values, but contains defaults about the directory to log files to, or configuration mode for find_devices.

The `direwolf\direwolf.conf` contains default values for direwolf, but settings like `call sign` and `ports` are automatically substituted in the container, based on the `.env` configuration, during container run, as part of running `start_direwolf.sh`.

## Services

## Containers

**Note** that the containers can be ran standalone, but the (minimal) scripting around each container was written to support full automation and with `compose` in mind. You'll need to set the approrpiate variables for the scripts when not using compose. This is pretty easy to follow, if you read the contents of the `.env` file defaults, and `compose.yaml`. You should not need to run the containers directly unless you are debugging an issue. If you don't want to use compose, you don't have to, but you'll need to create the appropriate command lines for yourself. Again, follow what `compose.yaml` is doing if you want to follow that route, it's not hard.

### Direwolf

The `direwolf` container runs Direwolf, this is located in the direwolf directory. The `start_direwolf.sh` script is used for finding soundcard/serial port using find_devices https://github.com/iontodirel/find_devices.

The `direwolf.conf` contains a basic Direwolf modem configuration, the `start_direwolf.sh` script uses *sed* to set the soundcard and serial port within the configuration file.

The container needs hardware access to USB and serial ports, so we can enumerate the hardware and have Direwolf use it. You can give the container granular access to the hardware or use the `--privileged` mode. When used in conjunction with `compose` and running Direwolf as a service, only `--privileged` mode is supported, as compose has no host side scripting capability. If this is important to you can still use the contaner, but run find_devices externally and replace management of the container startup with your own scripting.

To access the TCP servers from Direwolf, expose the appropriate ports to the host, this is not something you need to do if you use compose from the root directory.

### Aprx

This container runs `aprx`. 

### GPS

This container runs `gpsd` in daemon mode. Just like the Direwolf container, `find_devices` is used to find the serial port corresponding to the GPS hardware. Just like the Direwolf container, this requires USB access, and when used with compose we use the `--privileged` mode.

The `start_gpsd.sh` script is used to find the serial port, and start `gpsd`. `gpsd` typically runs a server on port 2947, expose the appropriate port when running the container so you can access the service.

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

## Linux host machine configuration

The Linux system requires virtually no configuration, as our containers and compose handles everything. The only real requirements are `git` and `Docker`.

### Raspberry Pi 4 with Raspbian 32-bit

Below is an example configuration done to setup the Docker APRS container to run on a fresh install Raspberry Pi.

**1. Setup the system for first time use.**


`sudo apt-get update` \
`sudo apt-get install git`


**2. Install Docker**, if on Rasphbian, according to official Docker documentation https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script.


`curl -fsSL https://get.docker.com -o get-docker.sh` \
`sudo sh ./get-docker.sh --dry-run`


**3. Configure Docker for rootless use** according to official Docker documentation https://docs.docker.com/engine/security/rootless/.


`sudo sh -eux <<EOF` \
`apt-get install -y uidmap` \
`EOF` \
`dockerd-rootless-setuptool.sh install`

    
**4. Clone the container repo.**

`git clone https://github.com/iontodirel/ham_docker_container` \
`cd ham_docker_container`

**5. Set or establish your configuration in the `.env` file.**

Modify the other configuration files as needed for your application.

**6. Build and run the containers.** *Creating the container will take a few minutes when done for the first time.*

`docker compose build` \
`docker compose up`

### Ubuntu 64-bit on Generic Intel hardware

**1. Setup the system for first time use.**

`sudo apt-get update` \
`sudo apt-get install git`

**2. Install Docker and setup Docker for rootless use**

Follow the official Docker instructions: https://docs.docker.com/engine/install/ubuntu/

**Note** instructions as similar to Raspbian, but are not explained to the same detail. Please just follow official Docker documentation.

**3. Clone the container repo.**

`git clone https://github.com/iontodirel/ham_docker_container` \
`cd ham_docker_container`

**4. Set or establish your configuration in the `.env` file.**

Modify the other configuration files as needed for your application.

**5. Build and run the containers.** *Creating the container will take a few minutes when done for the first time.*

`docker compose build`
`docker compose up`

## Resilience

- The audio soudcard can be connected to any USB port, *depending on your audio configuration*. Follow the instructions from find_devices about creating a find_devices configuration for your devices and circumstances: https://github.com/iontodirel/find_devices
- In case of a USB disconnect, Docker will automatically handle container restart.
- In case of Direwolf crashes, or other Direwolf failures, Docker will automatically handle container restart.
- An internet connection is not required after setting up a system.

## Handling system reboots and continuous operation

There are no needs for any hooks or scripts to run during system initialization. Docker runs automatically after boot by default, and the container policy to auto-restart, auto-restarts the container.

If you look in `compose.yaml`, this is handled with the `restart: always` policy.
