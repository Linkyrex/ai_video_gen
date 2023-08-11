#!/bin/bash

# Add logging function
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") $1"
}

function check_dependencies() {
    if ! command -v awk &> /dev/null
    then
        log "awk not found. Please install awk and try again."
        exit
    fi

    if ! command -v aws &> /dev/null
    then
        log "aws not found. Please install aws and try again."
        exit
    fi

    if ! command -v ffmpeg &> /dev/null
    then
        log "ffmpeg not found. Please install ffmpeg and try again."
        exit
    fi
}

function split_text_file() {
    awk 'BEGIN {RS = "\n
    "; FS = "\n"; filename = substr(FILENAME, 1, length(FILENAME) - 4); i = 1; outfile = sprintf(filename "_%04d.txt", i);} {segment = $0; outfile = sprintf(filename "_%04d.txt", ++i); print segment > outfile;}' "$1"

    log "Text splitting completed."
}

function synthesize_audio() {
    for file in _[0-9][0-9][0-9][0-9].txt; do
        text=$(<"$file")
        ssml_text="<speak><prosody rate='80%'>$text<break time='731ms'/></prosody></speak>"
        mp3_filename="${file%.txt}.mp3"
        if ! aws polly synthesize-speech --output-format mp3 --voice-id Matthew --engine neural --text-type ssml --text "$ssml_text" "$mp3_filename"; then
            log "Error: Failed to synthesize speech for $file."
            exit 1
        fi
    done

    log "Audio synthesis completed."
}

function create_video_files() {
    default_font_size=${FONT_SIZE:-37}
    line_spacing_value=${LINE_SPACING:-31}
    background_color=${BACKGROUND_COLOR:-black}
    echo "" > videos_to_concat.txt

    for file in _[0-9][0-9][0-9][0-9].txt; do
        audio_file="${file%.*}.mp3"
        if [ ! -f "$audio_file" ]; then
            log "Warning: No audio file found for $file. Skipping..."
            continue
        fi
        DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $audio_file)
        ffmpeg -f lavfi -i color=c=$background_color:s=1920x1080:d=$DURATION \
        -vf "drawtext=textfile=$file:fontsize=$default_font_size:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2:line_spacing=$line_spacing_value" \
        -c:v libx264 temp_video_$file.mp4
        ffmpeg -i temp_video_$file.mp4 -i $audio_file -c:v copy -c:a aac -strict experimental merged_$file.mp4
        rm temp_video_$file.mp4
        rm $file
        rm $audio_file
    done

    for file in $(ls merged_*.mp4 | sort -V); do
        echo "file '$file'" >> videos_to_concat.txt
    done

    ffmpeg -f concat -safe 0 -i videos_to_concat.txt -c copy final_video.mp4

    rm merged_*.mp4
    rm videos_to_concat.txt

    log "Processing completed. final_video.mp4 is ready."
}

log "-----------------------------"
log " Text to Video Conversion "
log "-----------------------------"

check_dependencies

txt_files=($(find . -maxdepth 1 -type f -name "*.txt"))
if [ ${#txt_files[@]} -eq 0 ]; then
    log "No .txt files found in the directory."
    exit 1
fi
log "Found ${#txt_files[@]} .txt files:"
for i in "${!txt_files[@]}"; do
    log "$i: ${txt_files[$i]}"
done

PS3="Select a file by typing its ID and pressing Enter: "
select textfile in "${txt_files[@]}"; do
    if [[ -n "$textfile" ]]; then
        break
    fi
done

if [[ -z "$textfile" ]]; then
    log "Invalid ID selected!"
    exit 1
fi

split_text_file "$textfile"

cleanup() {
    rm -f _*.txt
    rm -f *.mp3
    rm -f temp_video_*.mp4
    rm -f merged_*.mp4
    rm -f videos_to_concat.txt
}

trap 'cleanup' INT TERM

split_text_file "$textfile"

synthesize_audio

create_video_files

cleanup

log "Processing completed. final_video.mp4 is ready."
