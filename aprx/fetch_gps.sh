#!/bin/sh

# **************************************************************** #
# ham_docker_container - Containers for APRS and ham radio         #
# Version 0.1.0                                                    #
# https://github.com/iontodirel/ham_docker_container               #
# Copyright (c) 2023 Ion Todirel                                   #
# **************************************************************** #

: "${GPS_UTIL:=/gps_util/gps_util}"
: "${OUT_JSON:=output.json}"
: "${_GPS_CONTAINER_PORT:=2947}"
: "${_GPS_CONTAINER_SERVICE:=gps}"

# Check that the gps_util utility is found
if ! command -v "$GPS_UTIL" >/dev/null 2>&1; then
    echo "Error: Executable" \"$GPS_UTIL\"" not found"
    exit 1
fi

# Call gps_util
# https://github.com/iontodirel/gps_util
if ! $GPS_UTIL -h $_GPS_CONTAINER_SERVICE -p $_GPS_CONTAINER_PORT -o $OUT_JSON --no-stdout; then
    echo "Error: Failed to fetch GPS location"
    exit 1
fi

# if gps_util output file does not exist then exit
if ! test -f "$OUT_JSON"; then
    echo "Error: No output json file found \"$OUT_JSON\""
    exit 1
fi

lat=$(jq -r '.position_ddm_short.lat // ""' $OUT_JSON)
lon=$(jq -r '.position_ddm_short.lon // ""' $OUT_JSON)
day=$(jq -r '.utc_time.day // ""' $OUT_JSON)
hour=$(jq -r '.utc_time.hour // ""' $OUT_JSON)
min=$(jq -r '.utc_time.min // ""' $OUT_JSON)
# NOTE: set your own igate symbol
symTabId="I"
sym="&"
# NOTE: set your own igate comment
comment="APRX+Direwolf Containerized Fill-in TX iGate"

# check that position is not empty
if [ -z "$lat" ] || [ -z "$lon" ]; then
    echo "Lat or Long is empty"
    exit 1
fi

# 
#  Data Format:
# 
#     !   Lat  Sym  Lon  Sym Code   Comment
#     =
#    ------------------------------------------
#     1    8    1    9      1        0-43
#
#  Examples:
#
#    !4903.50N/07201.75W-Test 001234
#    !4903.50N/07201.75W-Test /A=001234
#    !49  .  N/072  .  W-
#

position_no_timestamp="!$lat$symTabId$lon$sym$comment"

# 
#  Data Format:
# 
#     /   Time  Lat   Sym  Lon  Sym Code   Comment
#     @
#    -----------------------------------------------
#     1    7     8     1    9      1        0-43
#
#  Examples:
#
#    /092345z4903.50N/07201.75W>Test1234
#    @092345/4903.50N/07201.75W>Test1234
#

position_with_timestamp="@$day$hour${min}z$lat$symTabId$lon$sym$comment"

echo "$position_with_timestamp\n"

exit 0