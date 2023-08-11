import logging
from moviepy.editor import VideoFileClip, concatenate_videoclips, AudioFileClip
from pathlib import Path
import os
import subprocess
import glob

def check_requirements():
    for command in ["awk", "aws", "ffmpeg"]:
        if not subprocess.run(["which", command], stdout=subprocess.DEVNULL).returncode == 0:
            print(f"{command} could not be found. Please install {command} and try again.")
            exit(1)

def list_and_select_files():
    txt_files = [f for f in glob.glob("./*.txt")]
    if not txt_files:
        print("No .txt files found in the directory.")
        exit(1)

    print(f"Found {len(txt_files)} .txt files:")
    for i, file in enumerate(txt_files):
        print(f"{i}: {file}")

    try:
        selection = int(input("Select a file by typing its ID and pressing Enter: "))
        return txt_files[selection]
    except (ValueError, IndexError):
        print("Invalid ID selected!")
        exit(1)

def split_text_file(textfile):
    command = [
        "awk",
        """BEGIN {RS = "\\n\\n"; FS = "\\n"; filename = substr(FILENAME, 1, length(FILENAME) - 4); i = 1; outfile = sprintf(filename "_%04d.txt", i);}
         {segment = $0; outfile = sprintf(filename "_%04d.txt", ++i); print segment > outfile;}""",
        textfile,
    ]
    subprocess.run(command)
    print("Text splitting completed.")

def synthesize_speech():
    for file in glob.glob("_[0-9][0-9][0-9][0-9].txt"):
        with open(file, "r") as f:
            text = f.read()
        
        ssml_text = f"<speak><prosody rate='80%'>{text}<break time='731ms'/></prosody></speak>"
        mp3_filename = f"{file[:-4]}.mp3"
        
        command = [
            "aws", "polly", "synthesize-speech",
            "--output-format", "mp3",
            "--voice-id", "Matthew",
            "--engine", "neural",
            "--text-type", "ssml",
            "--text", ssml_text,
            mp3_filename,
        ]
        subprocess.run(command)

    print("Audio synthesis completed.")

BACKGROUND_COLOR = "black"
FRAME_WIDTH = 1920
FRAME_HEIGHT = 1080
TEXT_BORDER = 0.1
TEXT_FONT_SIZE = 50
line_spacing_value = 50
def process_files():
    for file_name in sorted(os.listdir('.')):
        if file_name.startswith('_') and file_name.endswith('.txt'):
            audio_file = file_name[:-4] + ".mp3"
            if not os.path.isfile(audio_file):
                print(f"Warning: No audio file found for {file_name}. Skipping...")
                continue

            duration = get_audio_duration(audio_file)
            text_width, text_height = calculate_text_dimensions()

            generate_video_with_text(file_name, duration, text_width, text_height)
            merge_video_with_audio(file_name, audio_file)
            clean_up_temporary_files(file_name, audio_file)

def get_audio_duration(audio_file):
    return subprocess.getoutput(f'ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 {audio_file}')

def calculate_text_dimensions():
    text_width = int((1 - 2 * TEXT_BORDER) * FRAME_WIDTH)
    text_height = int((1 - 2 * TEXT_BORDER) * FRAME_HEIGHT)
    return text_width, text_height

def generate_video_with_text(file_name, duration, text_width, text_height):
    ffmpeg_command = f'''ffmpeg -f lavfi -i color=c={BACKGROUND_COLOR}:s={FRAME_WIDTH}x{FRAME_HEIGHT}:d={duration} \
    -vf "drawtext=textfile={file_name}:fontsize={TEXT_FONT_SIZE}:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2:line_spacing={line_spacing_value}" \
    -c:v libx264 temp_video_{file_name}.mp4'''
    os.system(ffmpeg_command)

def merge_video_with_audio(file_name, audio_file):
    merge_command = f'ffmpeg -i temp_video_{file_name}.mp4 -i {audio_file} -c:v copy -c:a aac -strict experimental merged_{file_name}.mp4'
    os.system(merge_command)

def clean_up_temporary_files(file_name, audio_file):
    os.remove(f'temp_video_{file_name}.mp4')
    os.remove(file_name)
    os.remove(audio_file)

def list_merged_files():
    for file_name in sorted(os.listdir('.')):
        if file_name.startswith('merged_') and file_name.endswith('.mp4'):
            with open('videos_to_concat.txt', 'a') as file:
                file.write(f"file '{file_name}'\n")

def process_videos():
    ffmpeg_command = "ffmpeg -f concat -safe 0 -i videos_to_concat.txt -c copy final_video.mp4"
    os.system(ffmpeg_command)
    logging.info("Processing completed. final_video.mp4 is ready.")

def cleanup(file_pattern):
    # Delete merged videos
    for file in Path(".").rglob(file_pattern):
        if file.name.startswith("merged_") and file.suffix == ".mp4":
            file.unlink()

    # Delete concat txt
    if Path("videos_to_concat.txt").exists():
        Path("videos_to_concat.txt").unlink()

def main():
    print("-------------------------------------------")
    print("      Text to Video Conversion Script      ")
    print("-------------------------------------------")
    print()

    check_requirements()
    textfile = list_and_select_files()
    split_text_file(textfile)
    synthesize_speech()
    process_files()
    list_merged_files()
    file_pattern = "./*.mp4"
    process_videos()
    cleanup(file_pattern)

if __name__ == "__main__":
    main()