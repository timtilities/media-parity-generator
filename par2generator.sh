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

# NOTES:
# - "files" mode is not compatible with movie/tv modes. if there are movies in the folders they will be scanned as movies and parified individually
#     I keep them in separate TLDs (not /data/Videos), so I have to run them separately anyway to put the par2 files somewhere other than 
#     /mnt/Videos. Not sure if there is a way around this - movie scan would need to be able to determine if it's a file directory (HOW??)
#     - Perhaps I could add folder markers - something like '.file' to the root of the directory to indicate it is NOT a movie/tv directory?
#
#
# - Add an exclude option when scanning - either just exclude first-level dirs, or use the find -X option and syntax
#   - The Family/Cartoon directory was treated as a movie folder and it generated par2s for each video (hundreds).
#     I redid this manually, but is there a way to detect this and handle it? maybe the Cartoon directory needs to be
#     fixed, not the script?
#
# - Add some kind of 'sync' option the will scan for NEW files
#   - It should NOT replace/update existing par2 files - that should only be done manually
#


# MANUALLY CREATE PAR2 FILES
# par2 create -r"$REDUNDANCY" -t8 -m4096 -b"$DEF_BLOCK_COUNT" -R -B "$SRC_PATH" "$DEST_PATH/PARFILE_NAME.par2" "$SRC_PATH/$FILES"*
#
# MANUALLY VERIFY PAR2 FILES:
# source Path/To/config.env
# par2 verify -T2 -m4096 -B "$MOVIE_DIR" -- "$PAR2_DIR/$MOVIE_ALIAS.par2"

############################################################################################################

# Default configuration variables:
# File containing the media list
MEDIA_LIST="media_list.txt"
# Destination directory where the par2 sets will be built
DEST_DIR="/mnt/Videos"
# Top level directory default (used if TLD from MEDIA_LIST is blank or in scan mode)
TOPLEVEL="/data/Videos"
# Force recreation of config.env files
CFG_FORCE=false
# Default redundancy - used if not specified in the list or during scan
DEF_REDUNDANCY="1"
# Recovery block count
DEF_BLOCK_COUNT="4000"
# Do not wait for confirmation
ASSUME_YES=false
# Automatic directory scan mode
SCAN_MODE=false


######################## CHANGE NOTHING BELOW THIS LINE ########################

# ANSI Color Codes
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_RED='\033[0;31m'

# Remove trailing / (just in case)
TOPLEVEL="${TOPLEVEL%/}"
DEST_DIR="${DEST_DIR%/}"

# initialize some vars
DETECT_MODE=""
ERROR=

##################################################################
# Display usage instructions
##################################################################
usage() {
    echo -e "${C_BOLD}Usage:${C_RESET} $0 [options]"
    echo -e "${C_BOLD}Options:${C_RESET}"
    echo "  -m, --media-list FILE       Path to the media list file (default: media_list.txt)"
    echo "  -d, --dest-dir DIR          Destination output directory for PAR2 sets (default: /scratch/Par2_Files/TestPars)"
    echo "  -t, --toplevel DIR          Default top-level source directory (default: /scratch/Par2_Files/TestVids)"
    echo "  -r, --redundancy PERCENT    Default redundancy percentage (default: 1)"
    echo "  -b, --recovery-blocks COUNT Number of recovery blocks (default: 4000)"
    echo "  -f, --force                 Force recreation of config and target directories (default: false)"
    echo "  -y, --yes                   Assume YES (do not ask for confirmation)"
    echo "  -s, --scan                  Scan the top-level directory tree (instead of using a media list) and determine media type automatically"
    echo "  -st, --scantv               Scan the top-level directory and treat as TV Series"
    echo "  -sm, --scanmovie            Scan the top-level directory and treat as movies"
    echo "  -sf, --scanfiles            Scan the top-level directory and treat as file/folder collections (Photos, MP3s, etc)"
    echo "  -h, --help                  Display this help message and exit"
    exit 0
}
##################################################################

##################################################################
# Function to create the config.env files
# Required Parameters:
# MOVIE_ALIAS:      Name of folder to place video(s) in
# MOVIE_DIR:        Folder containing the original videos
# MOVIE_FILENAME:   Base-name of the par2 files
# PAR2_DIR:         Path to folder containing the par2 files
##################################################################
create_config() {
    local cAlias=$1
    local cMovieDir=$2
    local cMovieFileName=$3
    local cPar2Dir=$4

    echo -e "${C_YELLOW}Creating env file: ${C_BOLD}$ENVFILE${C_RESET}"
    echo "# PAR2 Verification Configuration for '$ALIAS'" > "$ENVFILE"
    echo "# Generated on: $(date)" >> "$ENVFILE"
    echo "#" >> "$ENVFILE"
    echo "# TO VERIFY SOURCE FILES:" >> "$ENVFILE"
    echo "# source Path/To/This/config.env" >> "$ENVFILE"
    echo "# par2 verify -T2 -m4096 -B \"\$MOVIE_DIR\" -- \"\$PAR2_DIR/\$MOVIE_ALIAS.par2\"" >> "$ENVFILE"
    echo "" >> "$ENVFILE"
    echo "MOVIE_DIR=\"$cMovieDir\"" >> "$ENVFILE"
    echo "MOVIE_FILENAME=\"$cMovieFileName\"" >> "$ENVFILE"
    echo "MOVIE_ALIAS=\"$cAlias\"" >> "$ENVFILE"
    echo "REDUNDANCY=\"$REDUNDANCY\"" >> "$ENVFILE"
    echo "PAR2_DIR=\"$cPar2Dir\"" >> "$ENVFILE"
}
##################################################################

##################################################################
# Function to display config summary and get confirmation
##################################################################
summary_confirm() {
    echo -e "${C_CYAN}====================================================================${C_RESET}"
    echo -e "${C_BOLD}${C_GREEN} PAR2 Batch Generator Configuration Summary${C_RESET}"
    echo -e "${C_CYAN}====================================================================${C_RESET}"
    echo -e " Execution Mode      : $( [[ "$SCAN_MODE" == "true" ]] && echo -e "${C_YELLOW}Automatic Directory Scan (--scan)${C_RESET}" || echo -e "${C_YELLOW}Media List File ($MEDIA_LIST)${C_RESET}" )"
    echo -e " Destination Dir     : ${C_BOLD}$DEST_DIR${C_RESET}"
    echo -e " Top-Level Directory : ${C_BOLD}$TOPLEVEL${C_RESET}"
    echo -e " Default Redundancy  : ${C_BOLD}${DEF_REDUNDANCY}%${C_RESET}"
    echo -e " Recovery blocks     : ${C_BOLD}${DEF_BLOCK_COUNT}${C_RESET}"
    echo -e " Force Recreation    : ${C_BOLD}$CFG_FORCE${C_RESET}"
    echo -e " Skip Confirmation   : ${C_BOLD}$ASSUME_YES${C_RESET}"
    [[ "$SCAN_MODE" == "false" ]] && echo -e " Media List File     : ${C_BOLD}$MEDIA_LIST${C_RESET}"
    [[ "$SCAN_MODE" == "true" ]] && [[ "$DETECT_MODE" == "" ]] && echo -e " Scan Mode           : ${C_BOLD}Automatic${C_RESET}"
    [[ "$SCAN_MODE" == "true" ]] && [[ "$DETECT_MODE" != "" ]] && echo -e " Scan Mode           : ${C_BOLD}$DETECT_MODE${C_RESET}"
    echo -e " Log File            : ${C_BOLD}$MAINLOGFILE${C_RESET}"
    echo -e "${C_CYAN}====================================================================${C_RESET}"
}
##################################################################


##################################################################
# Function to deal with parity generation failures
# Required Parameters:
# DIRECTORY:      Directory which triggered the error
# MSG:            Message (reason) for the error
##################################################################
process_failure() {
    local DIRECTORY="$1"
    local MSG="$2"
    echo -e "${C_RED}Warning: File count ($FILECNT) exceeds BLOCK_COUNT ($DEF_BLOCK_COUNT) for ${DIRECTORY}!${C_RESET}"
    echo "\"$DIRECTORY\" -- FAILURE -- \"$MSG\"" >> "$FAILLOGFILE"
}
##################################################################

##################################################################
# Function to check the total file count in a directory
# Required Parameters:
# DIRECTORY:      Directory to check
##################################################################
check_dir_size() {
    local DIRECTORY="$1"
    local FILECNT=$(find "$DIRECTORY"* -type f | wc -l)
    if [ $FILECNT -gt $DEF_BLOCK_COUNT ]; then
        process_failure "$DIRECTORY" "File count ($FILECNT) exceeds BLOCK_COUNT ($DEF_BLOCK_COUNT)"
    else
        echo 0
    fi
}
##################################################################

##################################################################
# Function to process a movie
##################################################################
process_movie() {
    local SRC_PATH="$1"
    local FILE_NAME="$2"
    local WORK_DIR="$3"
    local ALIAS="$4"
    local CATEGORY="$5"
    local REDUNDANCY="$6"

    echo -e "${C_CYAN}==========================================================================================${C_RESET}"
    echo -e "Processing Movie: ${C_BOLD}${C_GREEN}${ALIAS}${C_RESET}"
    echo -e "${C_CYAN}------------------------------------------------------------------------------------------${C_RESET}"
    echo -e " Redundancy : ${C_YELLOW}${REDUNDANCY}%${C_RESET}"
    echo -e " Source     : $SRC_PATH"
    echo -e " Work Dir   : $WORK_DIR"
    echo -e " File Name  : $FILE_NAME"
    echo -e "${C_CYAN}==========================================================================================${C_RESET}"

    if [ ! -d "$SRC_PATH" ]; then
        echo -e "${C_RED}[-] Source directory not found: $SRC_PATH. Skipping.${C_RESET}"
        echo; echo
        return
    fi

    if [[ ! -d "$WORK_DIR" || "$CFG_FORCE" == "true" ]]; then
        echo -e "${C_BOLD}"
        du -sh "$SRC_PATH/$FILE_NAME"* 2>/dev/null || true
        local dirstat=$(check_dir_size "$SRC_DIR")
        if [ "$dirstat" == "0" ]; then
            # Create par2 working directory
            [ ! -d "$WORK_DIR" ] && mkdir -p "$WORK_DIR"
            # Create config files for future verification ease
            ENVFILE="$WORK_DIR/config.env"
            create_config "$ALIAS" "$SRC_PATH" "$FILE_NAME" "$WORK_DIR"

            par2 create -r"$REDUNDANCY" -t8 -m4096 -b"${DEF_BLOCK_COUNT}" -B "$SRC_PATH" "$WORK_DIR/$ALIAS" "$SRC_PATH/$FILE_NAME"*
            if [ "$?" != "0" ]; then
                process_failure "$SRC_PATH/$FILE_NAME" "Par2 creation failure. Check main log."
            fi
        else
            echo "$dirstat"
        fi           
    else
        echo -e "${C_YELLOW}[-] Target directory already exists. Skipping: $WORK_DIR${C_RESET}"
    fi
    echo -e "${C_CYAN}==========================================================================================${C_RESET}"
    echo; echo
}
##################################################################

##################################################################
# Function to process a TV Series
##################################################################
process_tv() {
    local TARGET="$1"
    local TLD="$2"
    local ALIAS="$3"
    local CATEGORY="$4"
    local REDUNDANCY="$5"

    SRC_DIR="$TLD/$TARGET"
    SERIES_DIR_NAME=$(basename "$TARGET")
    WORK_DIR="$DEST_DIR/$CATEGORY/$SERIES_DIR_NAME"

    echo -e "${C_MAGENTA}==========================================================================================${C_RESET}"
    echo -e "Processing TV Series: ${C_BOLD}${C_GREEN}$ALIAS${C_RESET} (${C_YELLOW}Redundancy: ${REDUNDANCY}%${C_RESET}${C_MAGENTA})"
    echo -e "${C_MAGENTA}------------------------------------------------------------------------------------------${C_RESET}"
    echo -e " Source   : $SRC_DIR"
    echo -e " Work Dir : $WORK_DIR"
    echo -e "${C_MAGENTA}==========================================================================================${C_RESET}"

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
            local dirstat=$(check_dir_size "$SEASON")
            if [ "$dirstat" == "0" ]; then
                # Create par2 working directory
                [ ! -d "$SEASON_WORK_DIR" ] && mkdir -p "$SEASON_WORK_DIR"
                # Create config files for future verification ease
                ENVFILE="$SEASON_WORK_DIR/config.env"
                create_config "$ALIAS.$PARSEASON" "$SEASON" "$SEASON" "$SEASON_WORK_DIR"

                # Create par2 files for the individual season
                par2 create -r"$REDUNDANCY" -t8 -m4096 -b"${DEF_BLOCK_COUNT}" -B "$SEASON" "$SEASON_WORK_DIR/$ALIAS.$PARSEASON" "$SEASON"/*
                if [ "$?" != "0" ]; then
                    process_failure "$SEASON" "Par2 creation failure. Check main log."
                fi
            else
                echo "$dirstat"
            fi
        else
            echo -e "${C_YELLOW}[-] Target directory already exists. Skipping: $SEASON_WORK_DIR${C_RESET}"
        fi
    done
    echo -e "${C_MAGENTA}==========================================================================================${C_RESET}"
    echo; echo
}
##################################################################

##################################################################
# Function to process a folder of files (e.g. Band / Music folders)
##################################################################
process_files() {
    local TARGET="$1"
    local TLD="$2"
    local ALIAS="$3"
    local CATEGORY="$4"
    local REDUNDANCY="$5"

    SRC_DIR="$TLD/$TARGET"

    if [ ! -d "$SRC_DIR" ]; then
        echo -e "${C_RED}[-] Source directory not found: $SRC_DIR. Skipping.${C_RESET}"
        echo; echo
        return
    fi

    # If ALIAS is blank, automatically iterate through all immediate subdirectories (e.g., bands under 80s)
    if [ -z "$ALIAS" ]; then
        echo -e "${C_GREEN}==========================================================================================${C_RESET}"
        echo -e "Scanning Parent Collection Directory: ${C_BOLD}$SRC_DIR${C_RESET}"
        echo -e "${C_GREEN}==========================================================================================${C_RESET}"
        
        for SUB_DIR in "$SRC_DIR"/*/; do
            [ -d "$SUB_DIR" ] || continue
            local sub_name=$(basename "$SUB_DIR")
            local sub_target="$TARGET/$sub_name"
            process_files "$sub_target" "$TLD" "$sub_name" "$CATEGORY" "$REDUNDANCY"
        done
        return
    fi

    # Otherwise, process this specific artist/band folder as a single recursive PAR2 set
    local DIR_NAME=$(basename "$TARGET")
    local WORK_DIR="$DEST_DIR/$CATEGORY/$DIR_NAME"

    echo -e "${C_GREEN}==========================================================================================${C_RESET}"
    echo -e "Processing Folder Collection: ${C_BOLD}${C_GREEN}$ALIAS${C_RESET} (${C_YELLOW}Redundancy: ${REDUNDANCY}%${C_RESET}${C_GREEN})"
    echo -e "${C_GREEN}------------------------------------------------------------------------------------------${C_RESET}"
    echo -e " Source   : $SRC_DIR"
    echo -e " Work Dir : $WORK_DIR"
    echo -e "${C_GREEN}==========================================================================================${C_RESET}"

    #[ ! -d "$WORK_DIR" ] && mkdir -p "$WORK_DIR"

    echo -e "${C_BOLD}"
    du -sh "$SRC_DIR"
    if [[ ! -d "$WORK_DIR" || -z "$(ls -A "$WORK_DIR"/*.par2 2>/dev/null)" || "$CFG_FORCE" == "true" ]]; then
        local dirstat=$(check_dir_size "$SRC_DIR")
        if [ "$dirstat" == "0" ]; then
            # Create par2 working directory
            [ ! -d "$WORK_DIR" ] && mkdir -p "$WORK_DIR"
            # Create config files for future verification ease
            ENVFILE="$WORK_DIR/config.env"
            create_config "$ALIAS" "$SRC_DIR" "$SRC_DIR" "$WORK_DIR"

            # Create par2 files recursively (-R) to cover subfolders (like albums/Flashback) inside the band folder
            par2 create -R -r"$REDUNDANCY" -t8 -m4096 -b"${DEF_BLOCK_COUNT}" -B "$SRC_DIR" "$WORK_DIR/$ALIAS" "$SRC_DIR"/*
            if [ "$?" != "0" ]; then
                process_failure "$SRC_DIR" "Par2 creation failure. Check main log."
            fi
        else
            echo "$dirstat"
        fi        
    else
        echo -e "${C_YELLOW}[-] Target directory already exists or has PAR2 files. Skipping: $WORK_DIR${C_RESET}"
    fi
    echo -e "${C_GREEN}==========================================================================================${C_RESET}"
    echo; echo
}
##################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                       MAIN                            #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -m|--media-list) 
            MEDIA_LIST="$2"
            shift 
            ;;
        -d|--dest-dir) 
            DEST_DIR="${2%/}"
            shift
            ;;
        -t|--toplevel) 
            TOPLEVEL="${2%/}"
            shift 
            ;;
        -r|--redundancy) 
            DEF_REDUNDANCY="$2"
            shift 
            ;;
        -b|--recovery-blocks) 
            DEF_BLOCK_COUNT="$2"
            shift 
            ;;
        -f|--force) 
            CFG_FORCE=true 
            ;;
        -y|--yes)
            ASSUME_YES=true
            ;;
        -s|--scan)
            SCAN_MODE=true
            ;;
        -st|--scantv)
            SCAN_MODE=true
            DETECT_MODE="tv"
            ;;
        -sm|--scanmovies)
            SCAN_MODE=true
            DETECT_MODE="movie"
            ;;
        -sf|--scanfiles)
            SCAN_MODE=true
            DETECT_MODE="files"
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

# Verify important things exists
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

# Verify block count is at least 2000
DEF_BLOCK_COUNT=$(( DEF_BLOCK_COUNT < 2000 ? 2000 : DEF_BLOCK_COUNT ))

# Log files
MAINLOGFILE="$DEST_DIR/par2generator.log"
FAILLOGFILE="$DEST_DIR/par2gen-failures.log"


# Print a configuration summary
summary_confirm

# Wait for confirmation (unless ASSUME_YES)
if [ "$ASSUME_YES" == "false" ]; then
    read -p "Do you want to proceed with these settings? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${C_YELLOW}Aborted by user.${C_RESET}"
        exit 0
    fi
fi
echo ""

# Redirect all stdout and stderr to both the terminal and the master log file
exec > >(tee -a "$MAINLOGFILE") 2>&1

echo -e "${C_BLUE}====================================================================${C_RESET}"
echo -e "${C_BOLD}Starting PAR2 Generation: $(date)${C_RESET}"
echo -e "Log file: $MAINLOGFILE"
echo -e "${C_BLUE}====================================================================${C_RESET}"
echo ""

# Execute scan or read input file based on execution mode
if [[ "$SCAN_MODE" == "true" ]]; then
    echo -e "${C_YELLOW}Scanning '$TOPLEVEL' for media...${C_RESET}"

    # Detect TV Series (directories containing Season* or Extra* subdirectories)
    if [[ -z "$DETECT_MODE" || "$DETECT_MODE" == "tv" ]]; then
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
        done < <(find "$TOPLEVEL" -type d \( -iname "Season*" -o -iname "Extra*" \) -exec dirname {} \; | sort -u)
    fi

    # Detect Movies (video files not located inside any Season/Extra directory)
    if [[ -z "$DETECT_MODE" || "$DETECT_MODE" == "movie" ]]; then
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

            process_movie "$src_path" "$stem" "$work_dir" "$alias" "$category" "$DEF_REDUNDANCY"
        done < <(find "$TOPLEVEL" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.m4v" -o -iname "*.ts" \) | sort)
    fi

    # Detect Folder Collections (music/band folders under genre directories like /data/MP3s/80s/ACDC)
    # Scans depth 2 folders under TOPLEVEL that contain files and do NOT contain Season/Extra subfolders
    if [[ -z "$DETECT_MODE" || "$DETECT_MODE" == "files" ]]; then
        while IFS= read -r folder_dir; do
            [[ -z "$folder_dir" ]] && continue

            if [[ -z "$DETECT_MODE" ]]; then
                # Skip if it's a TV series folder
                if find "$folder_dir" -maxdepth 1 -type d \( -iname "Season*" -o -iname "Extra*" \) | grep -q .; then
                    continue
                fi
                # Skip if it contains movie files (handled by movie scan)
                if find "$folder_dir" -maxdepth 1 -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.m4v" -o -iname "*.ts" \) | grep -q .; then
                    continue
                fi
            fi

            rel_path="${folder_dir#$TOPLEVEL/}"
            [[ -z "$rel_path" || "$rel_path" == "$TOPLEVEL" ]] && continue

            if [[ "$rel_path" == */* ]]; then
                category="$(dirname "$rel_path")"
            else
                #category="Collections"
                category=""
            fi

            process_files "$rel_path" "$TOPLEVEL" "$(basename "$folder_dir")" "$category" "$DEF_REDUNDANCY"
        done < <(find "$TOPLEVEL" -mindepth 2 -maxdepth 2 -type d | sort)
    fi

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

        # Sanitize ALIAS to prevent accidental directory nesting if subfolders were included in ALIAS
        ALIAS="${ALIAS##*/}"

        # If ALIAS is omitted/blank, default it using the same naming mechanism as scan mode
        if [ -z "$ALIAS" ]; then
            if [[ "${TYPE,,}" == "movie" ]]; then
                local_file="${TARGET##*/}"
                ALIAS="${local_file%.*}"
            elif [[ "${TYPE,,}" == "tv" ]]; then
                ALIAS="$(basename "$TARGET")"
            fi
        fi

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
            files)
                process_files "$TARGET" "$TLD" "$ALIAS" "$CATEGORY" "$REDUNDANCY"
                ;;
            *)
                echo -e "${C_RED}[-] Unknown media type '$TYPE' for entry '$TARGET'. Skipping.${C_RESET}"
                ;;
        esac
    done < <(cat "$MEDIA_LIST")
fi

echo -e "${C_BLUE}====================================================================${C_RESET}"
echo -e "${C_BOLD}PAR2 Generation Completed: $(date)${C_RESET}"
echo -e "${C_BLUE}====================================================================${C_RESET}"
