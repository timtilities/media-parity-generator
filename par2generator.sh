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
# - The scan mode names the folders after the file (up to the extension). The media_file mode names them based on the alias. 
#     Do I want them to always match, or should I allow the alias? Should I have it default to the filename if the alias isn't provided?

# TO VERIFY PAR2 FILES:
# source Path/To/config.env
# par2 verify -T2 -m4096 -B "$MOVIE_DIR" -- "$PAR2_DIR/$MOVIE_ALIAS.par2"

############################################################################################################

# ANSI Color Codes
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_RED='\033[0;31m'

# Default configuration variables:
# File containing the media list
MEDIA_LIST="media_list.txt"
# Destination directory where the par2 sets will be built
DEST_DIR="/scratch/Par2_Files/TestPars"
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
    echo -e "${C_BOLD}Usage:${C_RESET} $0 [options]"
    echo -e "${C_BOLD}Options:${C_RESET}"
    echo "  -m, --media-list FILE     Path to the media list file (default: media_list.txt)"
    echo "  -d, --dest-dir DIR        Destination output directory for PAR2 sets (default: /scratch/Par2_Files/Videos)"
    echo "  -t, --toplevel DIR        Default top-level source directory (default: /data/Videos)"
    echo "  -r, --redundancy PERCENT  Default redundancy percentage (default: 7)"
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
        -d|--dest-dir|-b|--base-dir) 
            DEST_DIR="$2"
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
            echo -e "${C_RED}Unknown option: $1${C_RESET}" >&2
            echo "Use '$0 --help' for usage information." >&2
            exit 1
            ;;
    esac
    shift
done

# Log file
LOGFILE="$DEST_DIR/par2generator.log"

if [ ! -d "$DEST_DIR" ]; then
    echo -e "${C_RED}Destination directory '$DEST_DIR' does not exist! Exiting!${C_RESET}" >&2
    exit 1
fi

if [[ "$SCAN_MODE" == "true" && ! -d "$TOPLEVEL" ]]; then
    echo -e "${C_RED}Top-level directory '$TOPLEVEL' does not exist! Exiting!${C_RESET}" >&2
    exit 1
fi

if [[ "$SCAN_MODE" == "false" && ! -f "$MEDIA_LIST" ]]; then
    echo -e "${C_RED}Data file '$MEDIA_LIST' not found! Exiting!${C_RESET}" >&2
    exit 1
fi

# --- CONFIGURATION SUMMARY & CONFIRMATION PROMPT ---
echo -e "${C_CYAN}====================================================================${C_RESET}"
echo -e "${C_BOLD}${C_GREEN} PAR2 Batch Generator Configuration Summary${C_RESET}"
echo -e "${C_CYAN}====================================================================${C_RESET}"
echo -e " Execution Mode      : $( [[ "$SCAN_MODE" == "true" ]] && echo -e "${C_YELLOW}Automatic Directory Scan (--scan)${C_RESET}" || echo -e "${C_YELLOW}Media List File ($MEDIA_LIST)${C_RESET}" )"
echo -e " Destination Dir     : ${C_BOLD}$DEST_DIR${C_RESET}"
echo -e " Top-Level Directory : ${C_BOLD}$TOPLEVEL${C_RESET}"
echo -e " Default Redundancy  : ${C_BOLD}${DEF_REDUNDANCY}%${C_RESET}"
echo -e " Force Recreation    : ${C_BOLD}$CFG_FORCE${C_RESET}"
[[ "$SCAN_MODE" == "false" ]] && echo -e " Media List File     : ${C_BOLD}$MEDIA_LIST${C_RESET}"
echo -e " Log File            : ${C_BOLD}$LOGFILE${C_RESET}"
echo -e "${C_CYAN}====================================================================${C_RESET}"

read -p "Do you want to proceed with these settings? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${C_YELLOW}Aborted by user.${C_RESET}"
    exit 0
fi
echo ""

# Redirect all stdout and stderr to both the terminal and the master log file
exec > >(tee -a "$LOGFILE") 2>&1

echo -e "${C_BLUE}====================================================================${C_RESET}"
echo -e "${C_BOLD}Starting PAR2 Generation: $(date)${C_RESET}"
echo -e "Log file: $LOGFILE"
echo -e "${C_BLUE}====================================================================${C_RESET}"
echo ""

# Unified function to process and create PAR2 for a movie
process_movie() {
    local SRC_PATH="$1"
    local FILE_NAME="$2"
    local WORK_DIR="$3"
    local ALIAS="$4"
    local CATEGORY="$5"
    local REDUNDANCY="$6"

    echo -e "${C_CYAN}=========================================================================================="
    echo -e "Processing Movie: ${C_BOLD}${C_GREEN}$ALIAS${C_RESET}"
    echo -e "${C_CYAN}------------------------------------------------------------------------------------------${C_RESET}"
    echo -e " Redundancy : ${C_YELLOW}${REDUNDANCY}%${C_RESET}"
    echo -e " Source     : $SRC_PATH"
    echo -e " Work Dir   : $WORK_DIR"
    echo -e "${C_CYAN}==========================================================================================${C_RESET}"

    if [ ! -d "$SRC_PATH" ]; then
        echo -e "${C_RED}[-] Source directory not found: $SRC_PATH. Skipping.${C_RESET}"
        echo; echo
        return
    fi

    if [[ ! -d "$WORK_DIR" || "$CFG_FORCE" == "true" ]]; then
        mkdir -p "$WORK_DIR"
        echo -e "${C_BOLD}"
        du -sh "$SRC_PATH/$FILE_NAME"* 2>/dev/null || true

        ENVFILE="$WORK_DIR/config.env"
        echo -e "${C_YELLOW}Creating env file: ${C_BOLD}$ENVFILE${C_RESET}"
        echo "# PAR2 Verification Configuration for $ALIAS" > "$ENVFILE"
        echo "# Generated on: $(date)" >> "$ENVFILE"
        echo "MOVIE_DIR=\"$SRC_PATH\"" >> "$ENVFILE"
        echo "MOVIE_FILENAME=\"$FILE_NAME\"" >> "$ENVFILE"
        echo "MOVIE_ALIAS=\"$ALIAS\"" >> "$ENVFILE"
        echo "REDUNDANCY=\"$REDUNDANCY\"" >> "$ENVFILE"
        echo "PAR2_DIR=\"$WORK_DIR\"" >> "$ENVFILE"

        par2 create -r"$REDUNDANCY" -t8 -m4096 -b4000 -B "$SRC_PATH" "$WORK_DIR/$ALIAS" "$SRC_PATH/$FILE_NAME"*
        #echo -e "${C_GREEN}par2 create -r\"$REDUNDANCY\" -t8 -m4096 -b4000 -B \"$SRC_PATH\" \"$WORK_DIR/$ALIAS\" \"$SRC_PATH/$FILE_NAME\"*${C_RESET}"
    else
        echo -e "${C_YELLOW}[-] Target directory already exists. Skipping: $WORK_DIR${C_RESET}"
    fi
    echo -e "${C_CYAN}=========================================================================================="
    echo; echo
}

# Function to process a TV Series
process_tv() {
    local TARGET="$1"
    local TLD="$2"
    local ALIAS="$3"
    local CATEGORY="$4"
    local REDUNDANCY="$5"

    SRC_DIR="$TLD/$TARGET"
    SERIES_DIR_NAME=$(basename "$TARGET")
    WORK_DIR="$DEST_DIR/$CATEGORY/$SERIES_DIR_NAME"

    echo -e "${C_MAGENTA}=========================================================================================="
    echo -e "Processing TV Series: ${C_BOLD}${C_GREEN}$ALIAS${C_RESET} (${C_YELLOW}Redundancy: ${REDUNDANCY}%${C_RESET}${C_MAGENTA})"
    echo -e "${C_MAGENTA}------------------------------------------------------------------------------------------${C_RESET}"
    echo -e " Source   : $SRC_DIR"
    echo -e " Work Dir : $WORK_DIR"
    echo -e "${C_MAGENTA}=========================================================================================="

    if [ ! -d "$SRC_DIR" ]; then
        echo -e "${C_RED}[-] Source directory not found: $SRC_DIR. Skipping.${C_RESET}"
        echo; echo
        return
    fi

    [ ! -d "$WORK_DIR" ] && mkdir -p "$WORK_DIR"

    for SEASON in "$SRC_DIR"/Season* "$SRC_DIR"/Extra*; do
        [ -e "$SEASON" ] || continue

        PARSEASON=$(basename "$SEASON")
        SEASON_WORK_DIR="$WORK_DIR/$PARSEASON"

        echo -e "${C_BLUE}--------------------------------------------------------------------${C_RESET}"
        echo -e " ${C_BOLD}-> Season: ${C_YELLOW}$PARSEASON${C_RESET}"
        echo -e "${C_BLUE}--------------------------------------------------------------------${C_RESET}"

        echo -e "${C_BOLD}"
        du -sh "$SEASON"
        if [[ ! -d "$SEASON_WORK_DIR" || "$CFG_FORCE" == "true" ]]; then             
            [ ! -d "$SEASON_WORK_DIR" ] && mkdir -p "$SEASON_WORK_DIR"

            ENVFILE="$SEASON_WORK_DIR/config.env"
            echo -e "${C_YELLOW}Creating env file: ${C_BOLD}$ENVFILE${C_RESET}"
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
            echo -e "${C_YELLOW}[-] Target directory already exists. Skipping: $SEASON_WORK_DIR${C_RESET}"
        fi
    done
    echo -e "${C_MAGENTA}=========================================================================================="
    echo; echo
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                         MAIN                          #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# --- EXECUTION MODES ---

if [[ "$SCAN_MODE" == "true" ]]; then
    echo -e "${C_YELLOW}Scanning '$TOPLEVEL' for media...${C_RESET}"

    # Detect TV Series (directories containing Season* or Extra* subdirectories)
    while IFS= read -r series_dir; do
        [[ -z "$series_dir" ]] && continue
        
        rel_path="${series_dir#$TOPLEVEL/}"
        
        # Preserve intermediate folder if present (e.g. Other/TV Series/The IT Crowd -> category='Other/TV Series')
        if [[ "$rel_path" == */*/* ]]; then
            parent_dir="$(dirname "$rel_path")"
            category="$parent_dir"
        else
            category="${rel_path%%/*}"
        fi

        target_path="$rel_path"
        alias="$(basename "$series_dir")"

        process_tv "$target_path" "$TOPLEVEL" "$alias" "$category" "$DEF_REDUNDANCY"
    done < <(find "$TOPLEVEL" -type d \( -name "Season*" -o -name "Extra*" \) -exec dirname {} \; | sort -u)

    # Detect Movies (video files not located inside any Season/Extra directory)
    while IFS= read -r vid_file; do
        [[ -z "$vid_file" ]] && continue

        rel_path="${vid_file#$TOPLEVEL/}"

        # Skip if any path component is a Season or Extra folder (robust check for TV show episodes)
        skip_file=false
        IFS='/' read -ra path_parts <<< "$rel_path"
        for part in "${path_parts[@]}"; do
            if [[ "$part" =~ ^[Ss]eason ]] || [[ "$part" =~ ^[Ee]xtra ]]; then
                skip_file=true
                break
            fi
        done
        [[ "$skip_file" == "true" ]] && continue

        file_dir="$(dirname "$vid_file")"
        rel_dir="${file_dir#$TOPLEVEL/}"
        
        filename="$(basename "$vid_file")"
        stem="${filename%.*}"
        parent_dir="$(basename "$file_dir")"

        category="${rel_path%%/*}"

        src_path="$file_dir"
        file_name="$filename"
        alias="$stem"

        # If parent directory matches the movie title, place work_dir one level higher
        if [[ "${parent_dir,,}" == "${stem,,}" ]]; then
            work_dir="$DEST_DIR/$rel_dir"
        else
            work_dir="$DEST_DIR/$rel_dir/$stem"
        fi

        process_movie "$src_path" "$file_name" "$work_dir" "$alias" "$category" "$DEF_REDUNDANCY"
    done < <(find "$TOPLEVEL" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" -o -name "*.m4v" -o -name "*.ts" \) | sort)

else
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

        # Sanitize alias to prevent accidental directory nesting if subfolders were included in ALIAS
        ALIAS="${ALIAS##*/}"

        # Process based on media type
        case "${TYPE,,}" in
            movie)
                if [[ "$TARGET" == */* ]]; then
                    SUB_DIR="${TARGET%/*}"
                    FILE_NAME="${TARGET##*/}"
                else
                    SUB_DIR=""
                    FILE_NAME="$TARGET"
                fi

                if [ -n "$SUB_DIR" ]; then          
                    WORK_DIR="$DEST_DIR/$CATEGORY/$SUB_DIR/$ALIAS"
                    SRC_PATH="$TLD/$CATEGORY/$SUB_DIR"
                else
                    WORK_DIR="$DEST_DIR/$CATEGORY/$ALIAS"
                    SRC_PATH="$TLD/$CATEGORY"
                fi
                process_movie "$SRC_PATH" "$FILE_NAME" "$WORK_DIR" "$ALIAS" "$CATEGORY" "$REDUNDANCY"
                ;;
            tv)
                process_tv "$TARGET" "$TLD" "$ALIAS" "$CATEGORY" "$REDUNDANCY"
                ;;
            *)
                echo -e "${C_RED}[-] Unknown media type '$TYPE' for entry '$TARGET'. Skipping.${C_RESET}"
                ;;
        esac
    done < <(cat "$MEDIA_LIST")
fi

echo -e "${C_BLUE}===================================================================="
echo -e "${C_BOLD}PAR2 Generation Completed: $(date)${C_RESET}"
echo -e "${C_BLUE}===================================================================="
