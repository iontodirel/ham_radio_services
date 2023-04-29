# APRS Docker containers

Docker containers for running APRS on ham radio

## Goals

- Easy, fast, and painless deployment of radio services to any new Linux system
- Repeatability
- Reliability

## Limitations

- **Only Linux is currently supported**. This work is targeted at small, cheap and compact Linux embedded devices running radio services 24/7. Windows has limitations sharing hadware to Docker containers. Mac OS support could be added in the future, but running services 24/7 on Mac systems is not considered economical for this to be a priority.
- **Multiple sound cards of the same type and model are not supported**. If your system has two Signalink or two Digirig sound cards, it's not possible to uniquely identify one of each sound card of the same type. As a result any one of the two devices could be used. It is possible to identify each Signalink and Digirig individually, as they use different audio CODECs, however. While it is easily possible to modify the `start_direwolf.sh` to suit your needs, this project is specifically focused on *reliability* and *repeatabiliy*. This limitations comes from the fact that the USB descriptors in the USB CODECs are all the same for all the ICs of the same make or familly *(TI should be blamed for this)*, and different sound cards have the same identical name and description. I am working on this limitation, and I am looking for a software only solution involving the USB port the sound card is connected to. 
- **Only USB sound cards are supported**.
- **Only sound cards with built in VOX are currently supported**. This limitation comes from limitations of sharing USB serial ports to Docker. Docker can access serial ports, but it's not easily possible to identify the serial port associated with a particular Digirig for example, if your system has few. This can be make to work with additional settings, like mapping the Digirig serial port to a specific name, but doesn't out of the box if you use this project. You can modify `start_direwolf.sh` and `compose.yaml` to suit your needs.
- **No GPIO access**. You can change `compose.yaml` to satisfy your needs and expose GPIO. Support for this out of the box might be added later.

## Running

Run from the root directory.

Follow the configuration section first.

To build and run the container:

~~~~
docker compose build
docker compose up
~~~~

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

## Settings by soundcard

Set the variables `AUDIO_USB_NAME` and `AUDIO_USB_DESC` inside your `.env` file based on the soundcard you use.

Use Alsa's aplay and arecord tools, or find_devices from https://github.com/iontodirel/find_devices to find the name and description of your device.

### Signalink

~~~~
AUDIO_USB_NAME=USB Audio
AUDIO_USB_DESC=Texas Instruments
~~~~

### Digirig

~~~~
AUDIO_USB_NAME=USB PnP Sound Device
AUDIO_USB_DESC=C-Media
~~~~

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

~~~~
nano .env
~~~~

**6. Run the container.** *Creating the container will take a few minutes when done for the first time.*

~~~~
docker compose up
~~~~

### Ubuntu 64-bit on Generic Intel hardware

TBD

### Debian on Beaglebone

TBD

## Resilience

- The audio soudcard can be connected to any USB port.
- In case of a USB disconnect, Docker will automatically handle container restart.
- In case of Direwolf crashes, or other Direwolf failures, Docker will automatically handle container restart.
- An internet connection is not required after setting up a system.

## Handling Restarts

Use this to start the Docker container after a system reboot

TBD

## Typical architecture

![image](https://user-images.githubusercontent.com/30967482/235277013-740799a8-ca05-4f43-8490-08744999b220.png)

![image](https://user-images.githubusercontent.com/30967482/235277032-81deb506-e989-47af-a0c3-cab2234a729b.png)

![image](https://user-images.githubusercontent.com/30967482/235277047-6f01b786-3cd2-4611-a31f-1ba90c5baadc.png)


## Containers

Follow these details if you want to debug the containers.


### Direwolf container

Run from the direwolf directory.

To build the container: `docker build -t direwolf .`

To run the container: `docker container run --env-file ./../.env -p 8010:8000 -p 8020:8001 -t -d --device /dev/snd direwolf`

To shell into the container: `docker container run --env-file ./../.env -p 8010:8000 -p 8020:8001 --device /dev/snd --interactive --tty --entrypoint /bin/sh direwolf`

## Additional Settings

The `.env` file contains various defaults and should be only file that needs editing for any configuration. At minimum, set the `MYCALL` variable to your callsign.

The `DIREWOLF_HOST_AGWP_PORT` and `DIREWOLF_HOST_KISS_PORT` variables contains the ports exposed from the container to the host, and what APRS clients will be configured with.

If you have more than one audio device type, capable of both playback and rendering, use `AUDIO_USB_NAME` and `AUDIO_USB_DESC` to select it. Currently, multiple audio devices of the same type are not supported, ex: Two Signalink on the same system. This is because while we can detect them, we cannot disambiguate which one to use based on name or description, as they are all based on Texas Instruments CODECs, with the same USB descriptors and same name and description. Future work might address this issue by selecting devices based on USB port used.

The `direwolf\start_direwolf.sh` contains no hardcoded values, but contains defaults about directory to log files to, or configuration type for findind the Alsa devices.

The `direwolf\direwolf.conf` contains default values for direwolf, but settings like call sign and ports are substituted based on the `.env` configuration, during container run, as part of running `start_direwolf.sh`.
