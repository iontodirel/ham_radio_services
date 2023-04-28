# ham_docker_container

Docker containers for running APRS on ham radio

## Containers

### Direwolf container

To build the container: `docker build -t direwolf .`

To run the container: `docker container run -p 8010:8000 -p 8020:8001 --name direwolf -t -d --device /dev/snd direwolf`

To shell into the container: `docker container run -p 8010:8000 -p 8020:8001 --device /dev/snd --interactive --tty --entrypoint /bin/sh direwolf`
