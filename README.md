# ham_docker_container

Docker containers for running APRS on ham radio

## Containers

### Direwolf container

Run from the direwolf directory.

To build the container: `docker build -t direwolf .`

To run the container: `docker container run --env-file ./../.env -p 8010:8000 -p 8020:8001 -t -d --device /dev/snd direwolf`

To shell into the container: `docker container run --env-file ./../.env -p 8010:8000 -p 8020:8001 --device /dev/snd --interactive --tty --entrypoint /bin/sh direwolf`

## Running

Run from the root directory.

To build the container: `docker compose build`

To run: `docker compose up`

## Settings

The `.env` file contains various defaults and should be only file that needs editing for any configuration. At minimum, set the `MYCALL` variable to your callsign.

The `DIREWOLF_HOST_AGWP_PORT` and `DIREWOLF_HOST_KISS_PORT` variables contains the ports exposed from the container to the host, and what APRS clients will be configured with.

If you have more than one audio device type, capable of both playback and rendering, use `AUDIO_USB_NAME` and `AUDIO_USB_DESC` to select it. Currently, multiple audio devices of the same type are not supported, ex: Two Signalink on the same system. This is because while we can detect them, we cannot disambiguate which one to use based on name or description, as they are all based on Texas Instruments CODECs, with the same USB descriptors and same name and description. Future work might address this issue by selecting devices based on USB port used.

The `direwolf\start_direwolf.sh` contains no hardcoded values, but contains defaults about directory to log files to, or configuration type for findind the Alsa devices.

The `direwolf\direwolf.conf` contains default values for direwolf, but settings like call sign and ports are substituted based on the `.env` configuration, during container run, as part of running `start_direwolf.sh`.


