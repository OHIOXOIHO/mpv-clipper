# MPV Video Trimmer

A Lua script for [mpv](https://mpv.io/) player that allows you to easily cut video clips from streams or local files with optional hard-subtitled subtitles.

> **Note**: This script has been primarily tested on Windows. While it should work on Linux and macOS in theory, I haven't been able to test it on these platforms. If you try it on Linux or macOS, please report any issues or confirm if it works correctly. Your feedback is greatly appreciated!

## Features
- **Precise Trimming**: Define exact start and end timestamps to extract specific video segments.
> **Note**: For frame-by-frame accuracy, pair with [mpv-frame-stepper](https://github.com/OHIOXOIHO/mpv-frame-stepper).
- **Clip Export**: Save trimmed segments as `.mp4` files with optimized encoding options.
- **Hardsub Support**: Integrate active subtitles (internal or external) into the output video.
- **Stream Compatibility**: Process and save clips from online streaming sources (e.g., HTTP/HTTPS URLs).
- **Cross-Platform**: Seamlessly operates across Linux, macOS, and Windows environments.
- **Subtitle Management**: Automatically detect, trim, and synchronize subtitles with the selected clip.
- **User Feedback**: Display on-screen notifications for operation status and error messages.

## Dependencies
- **mpv**: Requires mpv with Lua scripting support. Install via [mpv.io](https://mpv.io/installation/).
- **FFmpeg**: Essential for video cutting, re-encoding, and subtitle processing. Must be available in the system PATH.
  - **Linux**: Install with `sudo apt install ffmpeg` (Ubuntu/Debian) or `sudo pacman -S ffmpeg` (Arch).
  - **macOS**: Install via Homebrew with `brew install ffmpeg`.
  - **Windows**: Download from [ffmpeg.org](https://ffmpeg.org/download.html) and configure in PATH.

No additional Lua libraries are required beyond mpv’s native modules (`mp`, `mp.utils`, `mp.msg`).

## Installation
1. Place the script in the mpv script directory:
   - **Linux/macOS**: `~/.config/mpv/scripts/mpv-clipper.lua`
   - **Windows**: `%APPDATA%\mpv\scripts\mpv-clipper.lua` or `C:\path\to\mpv\portable_config\scripts\mpv-clipper.lua`
2. Ensure FFmpeg is installed and accessible via the command line.
3. Launch a video or stream in mpv to activate the script automatically.

## Usage
1. Open a video or stream within mpv.
2. Utilize the following keybindings:
   - `Ctrl+s`: Set the start timestamp.
   - `Ctrl+e`: Set the end timestamp.
   - `Ctrl+x`: Export the clip without subtitles (uses copy mode for local files).
   - `Ctrl+h`: Export the clip with hardsubbed subtitles (requires re-encoding).

On-screen messages will provide confirmation or error details.

## Output Directory
- **Local Files**: Saved in the same directory as the source file, named as `filename_start-end_clip.mp4`.
- **Streams**: Saved to `~/Desktop/mpvstreamcut/` (Linux/macOS) or `%USERPROFILE%\Desktop\mpvstreamcut\` (Windows).
  - The directory is created automatically if it does not exist.
  - Stream filenames are derived from the URL and sanitized (e.g., `stream_start-end_clip.mp4`).

Temporary subtitle files (e.g., `trimmed_ext_subs.ass`) are stored in the system temporary directory (`/tmp` on Linux/macOS, `%TEMP%` on Windows) and deleted post-processing.

## Platform Notes
- **Linux**: Uses `$HOME` as the home directory and `/tmp` for temporary files. Directory creation employs `mkdir -p`.
- **macOS**: Identical to Linux configuration.
- **Windows**: Uses `%USERPROFILE%` as the home directory and `%TEMP%` for temporary files. Directory creation uses `mkdir`.

## Keybindings
No clashes with mpv’s defaults here:

| Action            | Key      | What It Does                  |
|-------------------|----------|-------------------------------|
| Set Start         | `Ctrl+s` | Marks where your clip begins. |
| Set End           | `Ctrl+e` | Marks where it ends.          |
| Cut Clip          | `Ctrl+x` | Saves without subtitles.      |
| Cut with Hardsub  | `Ctrl+h` | Saves with subtitles baked in.|

## How It Works
This section outlines the operational workflow of the script:

1. **Marking**: Captures timestamps using `mp.get_property_number("time-pos")` when `Ctrl+s` or `Ctrl+e` is pressed.
2. **Cutting**: Executes FFmpeg commands through `mp.command_native`:
   - For local files, employs `-c:v copy` and `-c:a copy` for efficient cutting without re-encoding (unless hardsubbing is enabled).
   - For streams, performs re-encoding with `libx264` for video and `aac` for audio to produce a playable `.mp4` file.
3. **Subtitles**:
   - External subtitles are detected via `sub-file` or `track-list` and trimmed using FFmpeg to align with the selected start/end times.
   - Internal subtitles are extracted from the video using FFmpeg and trimmed accordingly.
   - Hardsubbing applies FFmpeg’s `ass` filter to embed subtitles into the video.
4. **Cleanup**: Following hardsubbing, removes temporary subtitle files (e.g., `trimmed_ext_subs.ass`) to maintain a clean filesystem.

## Limitations
The following limitations should be noted:

- Requires FFmpeg to be present in the system PATH; operation will fail without it.
- Hardsubbing necessitates video re-encoding, which may increase processing time and slightly affect quality (utilizes `libx264` with CRF 23).
- Stream filenames may default to generic names (e.g., `stream_start-end_clip.mp4`) if the URL lacks a descriptive identifier.

## Contributing
Contributions to enhance this project are welcome:

- Fork the repository, implement changes, and submit a pull request.
- Suggest improvements such as alternative keybindings, enhanced error handling, or additional features (e.g., customizable output directories).
- Report issues or provide feedback by creating an issue in the repository.

## License
MIT License - Freely available for use, modification, and distribution. Refer to the LICENSE file for details.



