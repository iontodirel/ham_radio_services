#!/bin/sh

# find alsa sound card
usb_device=$(/find_devices/find_devices --list --name "$AUDIO_USB_NAME" --desc "$AUDIO_USB_DESC" --type "playback&capture" --no-verbose)
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

# if config file does not exist then exit
if ! test -f "$DIREWOLF_CONFIG_FILE"
then
    echo "No config file found $direwolf_config_file"
    exit 1
fi

# replace soundard id in direwolf.conf file
sed -i "s/ADEVICE.*/ADEVICE $usb_device/" $DIREWOLF_CONFIG_FILE

# replace callsign in direwolf.conf file
sed -i "s/MYCALL.*/MYCALL $MYCALL/" $DIREWOLF_CONFIG_FILE

# replace AGWPORT and KISSPORT in direwolf.conf file
sed -i "s/AGWPORT.*/AGWPORT $DIREWOLF_CONTAINER_AGWP_PORT/" $DIREWOLF_CONFIG_FILE
sed -i "s/KISSPORT.*/KISSPORT $DIREWOLF_CONTAINER_KISS_PORT/" $DIREWOLF_CONFIG_FILE

# start direwolf
echo "Starting direwolf with callsign '$MYCALL', device '$usb_device', and ports '$DIREWOLF_CONTAINER_AGWP_PORT', '$DIREWOLF_CONTAINER_KISS_PORT'"

/usr/bin/direwolf -t 0 -p -a 10 -c $DIREWOLF_CONFIG_FILE -l .
