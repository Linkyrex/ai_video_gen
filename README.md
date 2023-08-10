# Text to Video Converter

This script converts text files into videos with audio using AWS Polly for audio synthesis and ffmpeg for video processing.

## Requirements

Make sure you have the following programs installed:

- awk
- aws (Amazon Web Services CLI)
- ffmpeg

## Usage

1. Place your text files (.txt) in the same directory as the script.
2. Run the script using the following command:
   ```
   bash convert_text_to_video.sh
   ```
3. Follow the on-screen prompts to select a text file and generate the video.

## How It Works

The script performs the following steps:

1. Checks if the required programs (awk, aws, and ffmpeg) are installed.
2. Scans for .txt files in the current directory and lists them with an ID.
3. Prompts the user to select a file by ID.
4. Splits the selected text file into segments based on paragraphs.
5. Converts each segment of text to audio using AWS Polly.
6. Creates videos with text overlay by merging the audio and video together.
7. Concatenates all the videos to create a final video.
8. Cleans up temporary files.

## Getting Started

To get started with this script, follow these steps:

1. Clone the repository to your local machine.
2. Install the required programs (awk, aws, and ffmpeg).
3. Make the script executable by running the following command:
   ```
   chmod +x convert_text_to_video.sh
   ```
4. Place your text files in the same directory as the script.
5. Run the script using the command mentioned in the Usage section.

## Limitations

Please note the following limitations of this script:

- The script assumes that the input text files are in plain text format (.txt).
- AWS credentials must be properly configured in order to use AWS Polly for audio synthesis.

## Contributions

Contributions to improve the script are welcome! If you encounter any issues or have any suggestions, please open an issue or submit a pull request.

## License

This script is released under the MIT License. Please see the LICENSE file for more details.

## Credits

This script was developed by Linkyrex.