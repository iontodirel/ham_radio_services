#!/bin/sh

# find alsa sound card
# set configuration for Signalink USB Audio Card
usb_device=$(/find_devices/find_devices --list --name "USB Audio" --desc "Texas Instruments" --type "playback&capture" --no-verbose)
exit_code=$?

# exit if could not find usb device
if test -z "$usb_device"
then
    echo "No usb device found"
    exit 1
fi
if [ $exit_code -ne 0 ]
then
    echo "find_devices exited with exit code '$exit_code'"
    exit 1
fi

config_file="config.json"

# direwolf.conf file settings
direwolf_config_file=$(jq -r '.direwolf_config_file' $config_file)
mycall=$(jq -r '.mycall' $config_file)
awgp_port=$(jq -r '.awgp_port' $config_file)
kiss_port=$(jq -r '.kiss_port' $config_file)

# if config file does not exist then exit
if ! test -f "$direwolf_config_file"
then
    echo "No config file found $direwolf_config_file"
    exit 1
fi

# replace soundard id in direwolf.conf file
sed -i "s/ADEVICE.*/ADEVICE $usb_device/" $direwolf_config_file

# replace callsign in direwolf.conf file
sed -i "s/MYCALL.*/MYCALL $mycall/" $direwolf_config_file

# replace AGWPORT and KISSPORT in direwolf.conf file
sed -i "s/AGWPORT.*/AGWPORT $awgp_port/" $direwolf_config_file
sed -i "s/KISSPORT.*/KISSPORT $kiss_port/" $direwolf_config_file

# start direwolf
echo "Starting direwolf"

/usr/bin/direwolf -t 0 -p -a 10 -c $direwolf_config_file -l .
