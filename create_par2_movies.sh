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

# TO DO:
# - Make the default variables TOPLEVEL, DEF_REDUNDANCY & CFG_FORCE also available through CLI options
# - Add a mode to scan a directory tree and create par2 files for everything? Not sure how that would work since sometimes it isn't a single file.
# - Is there a way to combine the TVSeries script with this one?

# File containing the movie list
MOVIES_LIST="movie_list.txt"

# Base  directory where the season folders and par2 sets will be built
BASE_DIR="/scratch/Par2_Files/Videos"

# Log file
#LOGFILE="$BASE_DIR/par2_movies_batch_run_$(date +%Y%m%d_%H%M%S).log"
LOGFILE="$BASE_DIR/par2_movies_batch_run.log"

# Top level directory (only used in MOVIES declaration - not needed if defined directly there)
TOPLEVEL="/data/Videos"

# Force recreation of config.env for all sets
CFG_FORCE=false

# Default redundancy - used if not specified in MOVIES_LIST
DEF_REDUNDANCY="2"

# Check for movies list
if [[ ! -f "$MOVIES_LIST" ]]; then
    echo "Data file '$MOVIES_LIST' not found! Exiting!" >&2
    exit 1
fi

if [ ! -d "$BASE_DIR" ]; then
    echo "$BASE_DIR does not exist! Exiting!"
    exit 1
fi

# Redirect all stdout and stderr to both the terminal and the master log file
exec > >(tee -a "$LOGFILE") 2>&1

echo "===================================================================="
echo "Starting PAR2 Batch Generation (Movies): $(date)"
echo "Log file: $LOGFILE"
echo "===================================================================="
echo ""

# Loop through each movie listed in $MOVIES_LIST
while IFS=':' read -r MOVIE TLD MOVIE_ALIAS GENRE REDUNDANCY; do
    # Skip comments & empty lines
    [[ "$MOVIE" =~ ^#.*$ ]] || [[ -z "$MOVIE" ]] && continue
    # Strip Windows CR/LF
    MOVIE="${MOVIE//[$'\r']/}"
    TLD="${TLD//[$'\r']/}"
    MOVIE_ALIAS="${MOVIE_ALIAS//[$'\r']/}"
    GENRE="${GENRE//[$'\r']/}"
    REDUNDANCY="${REDUNDANCY//[$'\r']/}"
    # If TLD is blank, use $TOPLEVEL instead
    TLD="${TLD:-$TOPLEVEL}"
    # If REDUNDANCY is blank, use $DEF_REDUNDANCY instead
    REDUNDANCY="${REDUNDANCY:-$DEF_REDUNDANCY}"

    # Extract subfolder path and filename if a subfolder exists
    if [[ "$MOVIE" == */* ]]; then
        SUB_DIR="${MOVIE%/*}"
        FILE_NAME="${MOVIE##*/}"
    else
        SUB_DIR=""
        FILE_NAME="$MOVIE"
    fi

    # Include subfolder only if present
    if [ -n "$SUB_DIR" ]; then
        WORK_DIR="$BASE_DIR/$GENRE/$SUB_DIR/$MOVIE_ALIAS"
    else
        WORK_DIR="$BASE_DIR/$GENRE/$MOVIE_ALIAS"
    fi

    echo "=========================================================================================="
    echo "Processing Movie: $MOVIE"
    echo "Redundancy: ${REDUNDANCY}%"
    echo "Source: $TLD/$GENRE"
    echo "Work Dir: $WORK_DIR"
    echo "=================================="

    if [ ! -d "$TLD/$GENRE" ]; then
        echo "[-] Source directory not found: $TLD/$GENRE. Skipping."
        echo; echo
        continue
    fi

    # Process the movie entry
    if [[ ! -d "$WORK_DIR" || "$CFG_FORCE" == "true" ]]; then
        mkdir -p "$WORK_DIR"

        du -sh "$TLD/$GENRE/$MOVIE"*

        ENVFILE="$WORK_DIR/config.env"
        echo "Creating env file: $ENVFILE"
        echo "# PAR2 Verification Configuration for $MOVIE_ALIAS" > "$ENVFILE"
        echo "# Generated on: $(date)" >> "$ENVFILE"
        echo "MOVIE_DIR=\"$TLD/$GENRE\"" >> "$ENVFILE"
        echo "MOVIE_FILENAME=\"$MOVIE\"" >> "$ENVFILE"
        echo "MOVIE_ALIAS=\"$MOVIE_ALIAS\"" >> "$ENVFILE"
        echo "REDUNDANCY=\"$REDUNDANCY\"" >> "$ENVFILE"
        echo "PARS_DIR=\"$WORK_DIR\"" >> "$ENVFILE"

        # Create par2 files
        #echo "par2 create -r\"$REDUNDANCY\" -t8 -m4096 -b4000 -B \"$TLD/$GENRE\" \"$WORK_DIR/$MOVIE_ALIAS\" \"$TLD/$GENRE/$MOVIE\"*"
        #par2 create -r"$REDUNDANCY" -t8 -m4096 -b4000 -B "$TLD/$GENRE" "$WORK_DIR/$MOVIE_ALIAS" "$TLD/$GENRE/$MOVIE"*
        par2 create -r"$REDUNDANCY" -t8 -m4096 -b4000 -B "$TLD/$GENRE" "$WORK_DIR/$MOVIE_ALIAS" "$TLD/$GENRE/$MOVIE"*
    else
        echo "[-] Target directory already exists. Skipping:"
        echo " $WORK_DIR."
        echo "=========================================================================================="
        echo; echo
        continue
    fi
    echo "=========================================================================================="
    echo; echo
done < <(cat "$MOVIES_LIST")

echo "===================================================================="
echo "Movie Batch Generation Completed: $(date)"
echo "===================================================================="