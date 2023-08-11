#!/bin/bash

# ASCII GUI
echo "-------------------------------------------"
echo "      Text to Video Conversion Script      "
echo "-------------------------------------------"
echo

# Check for required programs
if ! command -v awk &> /dev/null
then
    echo "awk could not be found. Please install awk and try again."
    exit
fi

if ! command -v aws &> /dev/null
then
    echo "aws could not be found. Please install aws and try again."
    exit
fi

if ! command -v ffmpeg &> /dev/null
then
    echo "ffmpeg could not be found. Please install ffmpeg and try again."
    exit
fi

# Scan for .txt files in the current directory and list them with an ID
txt_files=($(find . -maxdepth 1 -type f -name "*.txt"))
if [ ${#txt_files[@]} -eq 0 ]; then
    echo "No .txt files found in the directory."
    exit 1
fi
echo "Found ${#txt_files[@]} .txt files:"
for i in "${!txt_files[@]}"; do
    echo "$i: ${txt_files[$i]}"
done

# Prompt user to select a file by ID
PS3="Select a file by typing its ID and pressing Enter: "
select textfile in "${txt_files[@]}"; do
    if [[ -n "$textfile" ]]; then
        break
    fi
done

if [[ -z "$textfile" ]]; then
    echo "Invalid ID selected!"
    exit 1
fi

# Process the file
awk '
BEGIN {
    RS = "\n\n";  # Two new lines to detect paragraphs
    FS = "\n";
    filename = substr(FILENAME, 1, length(FILENAME) - 4);  # Removing .txt extension
    i = 1;
    outfile = sprintf(filename "_%04d.txt", i);
}

{
    segment = $0;
    outfile = sprintf(filename "_%04d.txt", ++i);
    print segment > outfile;
}
' "$textfile"

echo "Text splitting completed."

cleanup() {
    # perform cleanup
    rm -f _*.txt
    rm -f *.mp3
    rm -f temp_video_*.mp4
    rm -f merged_*.mp4
    rm -f videos_to_concat.txt
}

trap 'cleanup' INT TERM # trap interrupts and perform cleanup

# Process the file
awk '
BEGIN {
    RS = "\n\n";  # Two new lines to detect paragraphs
    FS = "\n";
    filename = substr(FILENAME, 1, length(FILENAME) - 4);  # Removing .txt extension
    i = 1;
    outfile = sprintf(filename "_%04d.txt", i);
}

{
    segment = $0;
    outfile = sprintf(filename "_%04d.txt", ++i);
    print segment > outfile;
}
' "$textfile"

echo "Text splitting completed."

# Convert the split text to audio
for file in _[0-9][0-9][0-9][0-9].txt; do
    text=$(<"$file")
    
    # Wrap text with SSML tags
    ssml_text="<speak><prosody rate='80%'>$text<break time='731ms'/></prosody></speak>"
    
    mp3_filename="${file%.txt}.mp3"
    
    aws polly synthesize-speech \
        --output-format mp3 \
        --voice-id Matthew \
        --engine neural \
        --text-type ssml \
        --text "$ssml_text" \
        "$mp3_filename"
done

echo "Audio synthesis completed."

default_font_size=37
line_spacing_value=31  # Adjust this value to your preference.

# Create a list for ffmpeg to concatenate videos at the end
echo "" > videos_to_concat.txt

# Processing
for file in _[0-9][0-9][0-9][0-9].txt; do
    # Check if corresponding audio file exists
    audio_file="${file%.*}.mp3"
    if [ ! -f "$audio_file" ]; then
        echo "Warning: No audio file found for $file. Skipping..."
        continue
    fi

    # Get audio duration
    DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $audio_file)

    # Generate video with text overlay and audio
    BACKGROUND_COLOR="black"
    ffmpeg -f lavfi -i color=c=$BACKGROUND_COLOR:s=1920x1080:d=$DURATION \
    -i $audio_file \
    -vf "drawtext=textfile=$file:fontsize=$default_font_size:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2:line_spacing=$line_spacing_value" \
    -c:v libx264 -c:a aac -strict experimental final_video_$file.mp4

    rm temp_video_$file.mp4
    rm $file
    rm $audio_file
done

# List files in sorted order
for file in $(ls merged_*.mp4 | sort -V); do
    echo "file '$file'" >> videos_to_concat.txt
done

# Concatenate all videos
ffmpeg -f concat -safe 0 -i videos_to_concat.txt -c copy final_video.mp4

# Cleanup temp, merged, and list files
rm merged_*.mp4
rm videos_to_concat.txt

echo "Processing completed. final_video.mp4 is ready."
rm merged_*.mp4
rm videos_to_concat.txt

echo "Processing completed. final_video.mp4 is ready."

echo "Processing completed. final_video.mp4 is ready."
