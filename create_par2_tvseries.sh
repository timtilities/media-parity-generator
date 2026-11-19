#!/usr/bin/env bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
#                                                                                             #
#    MEDIA-PARITY-GENERATOR - LICENSE                                                         #
#                                                                                             #
#    Copyright (C) 2026  timtilities - https://github.com/timtilities/media-parity-generator  #
#                                                                                             #
#    This program is free software: you can redistribute it and/or modify                     #
#    it under the terms of the GNU General Public License as published by                     #
#    the Free Software Foundation, either version 3 of the License, or                        #
#    (at your option) any later version.                                                      #
#                                                                                             #
#    This program is distributed in the hope that it will be useful,                          #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of                           #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                            #
#    GNU General Public License for more details.                                             #
#                                                                                             #
#    You should have received a copy of the GNU General Public License                        #
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.                   #
#                                                                                             #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 




# Base directory where the par2 sets will be created
BASE_DIR="/scratch/Par2_Files/Videos/Other/TV_Series"

# Log file
LOGFILE="$BASE_DIR/par2_create_$(date +%Y%m%d_%H%M%S).log"

# Array mapping [SRCDIR]="TVSERIES_NAME:REDUNDANCY"
declare -A TVSERIES=(
    ["/data/Videos/Other/TV Series/Test1"]="Test1:5"
    ["/data/Videos/Other/TV Series/Test2"]="Test2:5"
    ["/data/Videos/Other/TV Series/Test3"]="Test3:5"
)

# Verify $BASE_DIR exists
if [ ! -d "$BASE_DIR" ]; then
                echo "$BASE_DIR does not exist! Exiting!"
                exit 1
fi

# Redirect to log file (and stdout)
exec > >(tee -a "$LOGFILE") 2>&1

echo "===================================================================="
echo "Starting PAR2 Batch Generation (TV Series): $(date)"
echo "Log file: $LOGFILE"
echo "===================================================================="
echo ""

# Loop through each TV series directory
for SRCDIR in "${!TVSERIES[@]}"; do
    # Split the stored value into TVSERIES_NAME and REDUNDANCY using ':' as a delimiter
    IFS=':' read -r TVSERIES_NAME REDUNDANCY <<< "${TVSERIES[$SRCDIR]}"

    TVSERIES_DIR=$(basename "$SRCDIR")
    WORK_DIR="$BASE_DIR/$TVSERIES_DIR"

    echo "===================================================================="
    echo "Processing TV Series: $TVSERIES_NAME (Redundancy: ${REDUNDANCY}%)"
    echo "Source: $SRCDIR"
    echo "===================================================================="

    if [ ! -d "$SRCDIR" ]; then
        echo "[-] Source directory not found: $SRCDIR. Skipping."
        continue
    fi

    [ ! -d "$WORK_DIR" ] && mkdir -p "$WORK_DIR"

    for SEASON in "$SRCDIR/"Season*; do
        [ -e "$SEASON" ] || continue

        PARSEASON=$(basename "$SEASON")
        SEASON_WORK_DIR="$WORK_DIR/$PARSEASON"

        echo "--------------------------------------------------------------------"
        echo " -> Season: $PARSEASON"
        echo "--------------------------------------------------------------------"

        du -sh "$SEASON"
        [ ! -d "$SEASON_WORK_DIR" ] && mkdir -p "$SEASON_WORK_DIR"

        # Create par2 files
        par2 create -r"$REDUNDANCY" -t8 -m4096 -b4000 -B "$SEASON" "$SEASON_WORK_DIR/$TVSERIES_NAME.$PARSEASON" "$SEASON"/*
    done

    echo ""
done
