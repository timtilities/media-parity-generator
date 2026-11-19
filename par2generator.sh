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

# Added a directory scan mode
# Updated process_videos() to deal with subfolders correctly

# TO DO:
# - Add a mode to scan a directory tree and create par2 files for everything? Not sure how that would work since sometimes it isn't a single file. (Implemented via --scan)

# TO VERIFY PAR2 FILES:
# source Path/To/config.env
# par2 verify -T2 -m4096 -B "$MOVIE_DIR" -- "$PAR2_DIR/$MOVIE_ALIAS.par2"

############################################################################################################

# Default configuration variables:
# File containing the media list
MEDIA_LIST="media_list.txt"
# Base directory where the par2 sets will be built
BASE_DIR="/scratch/Par2_Files/TestPars"
# Top level directory default (used if TLD from MEDIA_LIST is blank or in scan mode)
TOPLEVEL="/scratch/Par2_Files/TestVids"
# Force recreation of config.env directories
CFG_FORCE=false
# Default redundancy - used if not specified in the list or during scan
DEF_REDUNDANCY="1"
# Automatic directory scan mode
SCAN_MODE=false

# Display usage instructions
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -m, --media-list FILE     Path to the media list file (default: media_list.txt)"
    echo "  -b, --base-dir DIR        Base output directory for PAR2 sets (default: /scratch/Par2_Files/Videos)"
    echo "  -t, --toplevel DIR        Default top-level source directory (default: /data/Videos)"
    echo "  -r, --r percentage        Default redundancy percentage (default: 7)"
    echo "  -s, --scan                Automatically scan the top-level directory tree instead of using a media list"
    echo "  -f, --force               Force recreation of config and target directories (default: false)"
    echo "  -h, --help                Display this help message and exit"
    exit 0
}

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -m|--media-list) 
            MEDIA_LIST="$2"
            shift 
            ;;
        -b|--base-dir) 
            BASE_DIR="$2"
            shift 
            ;;
        -t|--toplevel) 
            TOPLEVEL="$2"
            shift 
            ;;
        -r|--redundancy) 
            DEF_REDUNDANCY="$2"
            shift 
            ;;
        -s|--scan)
            SCAN_MODE=true
            ;;
        -f|--force) 
            CFG_FORCE=true 
            ;;
        -h|--help) 
            usage 
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use '$0 --help' for usage information." >&2
            exit 1
            ;;
    esac
    shift
done

# Log file
LOGFILE="$BASE_DIR/par2generator.log"

if [ ! -d "$BASE_DIR" ]; then
    echo "$BASE_DIR does not exist! Exiting!" >&2
    exit 1
fi

# Log redirection
exec > >(tee -a "$LOGFILE") 2>&1

echo "===================================================================="
echo "Starting PAR2 Generation: $(date)"
echo "Log file: $LOGFILE"
echo "Mode: $( [[ "$SCAN_MODE" == "true" ]] && echo "Automatic Directory Scan" || echo "Media List File ($MEDIA_LIST)" )"
echo "===================================================================="
echo ""

# Function to process a Movie entry
process_movie() {
    local TARGET="$1"
    local TLD="$2"
    local ALIAS="$3"
    local CATEGORY="$4"
    local REDUNDANCY="$5"

    # Extract subfolder path and filename if a subfolder exists
    if [[ "$TARGET" == */* ]]; then
        SUB_DIR="${TARGET%/*}"
        FILE_NAME="${TARGET##*/}"
    else
        SUB_DIR=""
        FILE_NAME="$TARGET"
    fi

    # Include subfolder only if present
    if [ -n "$SUB_DIR" ]; then          
        WORK_DIR="$BASE_DIR/$CATEGORY/$SUB_DIR/$ALIAS"
        SRC_PATH="$TLD/$CATEGORY/$SUB_DIR"
    else
        WORK_DIR="$BASE_DIR/$CATEGORY/$ALIAS"
        SRC_PATH="$TLD/$CATEGORY"
    fi

    echo "=========================================================================================="
    echo "Processing Movie: $TARGET"
    echo "Redundancy: ${REDUNDANCY}%"
    echo "Source: $SRC_PATH"
    echo "Work Dir: $WORK_DIR"
    echo "=================================="

    if [ ! -d "$SRC_PATH" ]; then
        echo "[-] Source directory not found: $SRC_PATH. Skipping."
        echo; echo
        return
    fi

    if [[ ! -d "$WORK_DIR" || "$CFG_FORCE" == "true" ]]; then
        mkdir -p "$WORK_DIR"
        du -sh "$SRC_PATH/$FILE_NAME"* 2>/dev/null || true

        ENVFILE="$WORK_DIR/config.env"
        echo "Creating env file: $ENVFILE"
        echo "# PAR2 Verification Configuration for $ALIAS" > "$ENVFILE"
        echo "# Generated on: $(date)" >> "$ENVFILE"
        echo "MOVIE_DIR=\"$SRC_PATH\"" >> "$ENVFILE"
        echo "MOVIE_FILENAME=\"$FILE_NAME\"" >> "$ENVFILE"
        echo "MOVIE_ALIAS=\"$ALIAS\"" >> "$ENVFILE"
        echo "REDUNDANCY=\"$REDUNDANCY\"" >> "$ENVFILE"
        echo "PAR2_DIR=\"$WORK_DIR\"" >> "$ENVFILE"

        par2 create -r"$REDUNDANCY" -t8 -m4096 -b4000 -B "$SRC_PATH" "$WORK_DIR/$ALIAS" "$SRC_PATH/$FILE_NAME"*
        echo "par2 create -r\"$REDUNDANCY\" -t8 -m4096 -b4000 -B \"$SRC_PATH\" \"$WORK_DIR/$ALIAS\" \"$SRC_PATH/$FILE_NAME\"*"
    else
        echo "[-] Target directory already exists. Skipping: $WORK_DIR"
    fi
    echo "=========================================================================================="
    echo; echo
}

# Function to process a TV Series entry
process_tv() {
    local TARGET="$1"
    local TLD="$2"
    local ALIAS="$3"
    local CATEGORY="$4"
    local REDUNDANCY="$5"

    SRC_DIR="$TLD/$TARGET"
    SERIES_DIR_NAME=$(basename "$TARGET")
    WORK_DIR="$BASE_DIR/$CATEGORY/$SERIES_DIR_NAME"

    echo "=========================================================================================="
    echo "Processing TV Series: $ALIAS (Redundancy: ${REDUNDANCY}%)"
    echo "Source: $SRC_DIR"
    echo "Work Dir: $WORK_DIR"
    echo "=================================="

    if [ ! -d "$SRC_DIR" ]; then
        echo "[-] Source directory not found: $SRC_DIR. Skipping."
        echo; echo
        return
    fi

    [ ! -d "$WORK_DIR" ] && mkdir -p "$WORK_DIR"

    for SEASON in "$SRC_DIR"/Season* "$SRC_DIR"/Extra*; do
        [ -e "$SEASON" ] || continue

        PARSEASON=$(basename "$SEASON")
        SEASON_WORK_DIR="$WORK_DIR/$PARSEASON"

        echo "--------------------------------------------------------------------"
        echo " -> Season: $PARSEASON"
        echo "--------------------------------------------------------------------"

        du -sh "$SEASON"
        if [[ ! -d "$SEASON_WORK_DIR" || "$CFG_FORCE" == "true" ]]; then             
            [ ! -d "$SEASON_WORK_DIR" ] && mkdir -p "$SEASON_WORK_DIR"

            ENVFILE="$SEASON_WORK_DIR/config.env"
            echo "Creating env file: $ENVFILE"
            echo "# PAR2 Verification Configuration for $ALIAS" > "$ENVFILE"
            echo "# Generated on: $(date)" >> "$ENVFILE"
            echo "MOVIE_DIR=\"$SEASON\"" >> "$ENVFILE"
            echo "MOVIE_FILENAME=\"$SEASON\"" >> "$ENVFILE"
            echo "MOVIE_ALIAS=\"$ALIAS.$PARSEASON\"" >> "$ENVFILE"
            echo "REDUNDANCY=\"$REDUNDANCY\"" >> "$ENVFILE"
            echo "PAR2_DIR=\"$SEASON_WORK_DIR\"" >> "$ENVFILE"

            # Create par2 files for the individual season
            par2 create -r"$REDUNDANCY" -t8 -m4096 -b4000 -B "$SEASON" "$SEASON_WORK_DIR/$ALIAS.$PARSEASON" "$SEASON"/*
        else
            echo "[-] Target directory already exists. Skipping: $SEASON_WORK_DIR"
        fi
    done
    echo "=========================================================================================="
    echo; echo
}

# --- EXECUTION MODES ---

if [[ "$SCAN_MODE" == "true" ]]; then
    if [ ! -d "$TOPLEVEL" ]; then
        echo "Top-level directory '$TOPLEVEL' does not exist! Exiting!" >&2
        exit 1
    fi

    echo "Scanning '$TOPLEVEL' for media..."

    # Detect TV Series (directories containing Season* or Extra* subdirectories)
    while IFS= read -r series_dir; do
        [[ -z "$series_dir" ]] && continue
        
        rel_path="${series_dir#$TOPLEVEL/}"
        category="${rel_path%%/*}"
        target_path="$rel_path"
        alias="$(basename "$series_dir")"

        process_tv "$target_path" "$TOPLEVEL" "$alias" "$category" "$DEF_REDUNDANCY"
    done < <(find "$TOPLEVEL" -type d \( -name "Season*" -o -name "Extra*" \) -exec dirname {} \; | sort -u)

    # Detect Movies (video files not located inside any Season/Extra directory)
    while IFS= read -r vid_file; do
        [[ -z "$vid_file" ]] && continue

        # Skip if the file resides inside a Season or Extra directory structure
        if [[ "$vid_file" =~ /Season[0-9]*[/] ]] || [[ "$vid_file" =~ /Extra[/] ]]; then
            continue
        fi

        rel_path="${vid_file#$TOPLEVEL/}"
        category="${rel_path%%/*}"
        target_path="${rel_path#*/}"
        filename="$(basename "$vid_file")"
        alias="${filename%.*}"

        process_movie "$target_path" "$TOPLEVEL" "$alias" "$category" "$DEF_REDUNDANCY"
    done < <(find "$TOPLEVEL" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" -o -name "*.m4v" -o -name "*.ts" \) | sort)

else
    # Check for media list file in standard mode
    if [[ ! -f "$MEDIA_LIST" ]]; then
        echo "Data file '$MEDIA_LIST' not found! Exiting!" >&2
        exit 1
    fi

    # Loop through each entry listed in $MEDIA_LIST
    while IFS=':' read -r TYPE TARGET TLD ALIAS CATEGORY REDUNDANCY; do
        # Skip comments & empty lines
        [[ "$TYPE" =~ ^#.*$ ]] || [[ -z "$TYPE" ]] && continue

        # Strip Windows CR/LF from all fields
        TYPE="${TYPE//[$'\r']/}"
        TARGET="${TARGET//[$'\r']/}"
        TLD="${TLD//[$'\r']/}"
        ALIAS="${ALIAS//[$'\r']/}"
        CATEGORY="${CATEGORY//[$'\r']/}"
        REDUNDANCY="${REDUNDANCY//[$'\r']/}"

        # Apply defaults if blank
        TLD="${TLD:-$TOPLEVEL}"
        REDUNDANCY="${REDUNDANCY:-$DEF_REDUNDANCY}"

        case "${TYPE,,}" in
            movie)
                process_movie "$TARGET" "$TLD" "$ALIAS" "$CATEGORY" "$REDUNDANCY"
                ;;
            tv)
                process_tv "$TARGET" "$TLD" "$ALIAS" "$CATEGORY" "$REDUNDANCY"
                ;;
            *)
                echo "[-] Unknown media type '$TYPE' for entry '$TARGET'. Skipping."
                ;;
        esac
    done < <(cat "$MEDIA_LIST")
fi

echo "===================================================================="
echo "PAR2 Generation Completed: $(date)"
echo "===================================================================="