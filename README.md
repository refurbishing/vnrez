# VNREZ Tool [<img src="./assets/logo.png" width="225" align="left" alt="VNREZ Logo">](https://github.com/refurbishing/vnrez)

#### Make Recordings & Screenshots and upload them to your favorite file hosts on Linux with support for region, GIF, audio and URL Shortening at ease.

[![Total Commits](https://img.shields.io/github/commit-activity/t/refurbishing/vnrez?style=flat&logo=github&label=Commits&labelColor=%230f0f0f&color=%23191919)](https://github.com/refurbishing/vnrez/commits/)
<br>
[![Last commit](https://img.shields.io/github/last-commit/refurbishing/vnrez?style=flat&logo=git&logoColor=d16d38&label=Activity&labelColor=%230F0F0F&color=1A1A1A)](https://github.com/refurbishing/vnrez/commits/)
<br><br><br><br>

## Dependencies

- **Screenshot**: `flameshot` or `grimblast` (not package)
- **Wayland**: `jq`, `wl-clipboard`, `slurp` & `wf-recorder` or `wl-screenrec`
- **COSMIC & GNOME / KDE Wayland**: `jq`, `wl-clipboard` & `kooha` or `io.github.seadve.Kooha`
- **X11**: `jq`, `xclip`, `slop` & `ffmpeg`

<details>
<summary>How to install them?</summary>

Go to your prefered terminal and execute this command depending on your Distro.
| Compositor | Distribution | Instructions |
| ------------------- | ----------------------- | ----------------------------------------------------------------------------------------------------- |
| **Wayland** | **Debian/Ubuntu** | `sudo apt install wf-recorder jq wl-clipboard slurp` or `sudo apt install wl-screenrec jq wl-clipboard slurp` |
| **Wayland** | **Fedora** | `sudo dnf install wf-recorder jq wl-clipboard slurp` or `sudo dnf install wl-screenrec jq wl-clipboard slurp` |
| **Wayland** | **Arch** | `sudo pacman -S wf-recorder jq wl-clipboard slurp` or `sudo pacman -S wl-screenrec jq wl-clipboard slurp` |
| **Wayland** | **Gentoo** | `sudo emerge -av gui-apps/wf-recorder app-misc/jq x11-misc/wl-clipboard gui-apps/slurp` or `sudo emerge -av media-video/wl-screenrec app-misc/jq x11-misc/wl-clipboard gui-apps/slurp` |

| Compositor | Distribution      | Instructions                                                                  |
| ---------- | ----------------- | ----------------------------------------------------------------------------- |
| **X11**    | **Debian/Ubuntu** | `sudo apt install ffmpeg jq xclip slop`                                       |
| **X11**    | **Fedora**        | `sudo dnf install ffmpeg jq xclip slop`                                       |
| **X11**    | **Arch**          | `sudo pacman -S ffmpeg jq xclip slop`                                         |
| **X11**    | **Gentoo**        | `sudo emerge -av media-video/ffmpeg app-misc/jq x11-misc/xclip x11-misc/slop` |

| Compositor                       | Distribution      | Instructions                                                          |
| -------------------------------- | ----------------- | --------------------------------------------------------------------- |
| **COSMIC & GNOME / KDE Wayland** | **Debian/Ubuntu** | `sudo apt install kooha jq wl-clipboard`                              |
| **COSMIC & GNOME / KDE Wayland** | **Fedora**        | `sudo dnf install jq wl-clipboard` and `sudo flatpak install io.github.seadve.Kooha` |
| **COSMIC & GNOME / KDE Wayland** | **Arch**          | `sudo pacman -S kooha jq wl-clipboard`                                |
| **COSMIC & GNOME / KDE Wayland** | **Gentoo**        | `sudo emerge -av media-video/kooha app-misc/jq x11-misc/wl-clipboard` |

 </details>

<details>
<summary>Which Services Are supported?</summary>
By default you can use these:
- [e-z](https://e-z.host)
- [nest](https://nest.rip)

You can always just use the **custom** option which will allow all json image hosts uploaders.
or you could just choose **none** which will just copy the file directly to your clipboard
</details>


## Installation

[![vnrez](https://img.shields.io/badge/AVAILABLE_ON_THE_AUR-333232?style=for-the-badge&logo=arch-linux&logoColor=3d67db&labelColor=%23171717)](https://aur.archlinux.org/packages/vnrez)


```bash
git clone https://github.com/refurbishing/vnrez
cd vnrez
# [!] Start the Script to Create the Configuration file
./vnrez.sh
```

<details>
<summary>How to get my API KEY?</summary>
Log in to Your Preferred File Host, Go to Account Settings, and Copy your API KEY<br>
Now paste that API KEY when doing the initial setup.
</details>

## Arguments

- `--help (-h)` show the list of arguments
- `upload (-u)` upload specified video files (mp4, mkv, webm, gif)
- `config` open the configuration file in the default text editor
- `reinstall` reinstall the configuration file with default settings
- `auto` run with default settings without using a config file
- `add` create a service file to add another service 

### Screenshot
 <small><strong>case: shot</strong></small>
- `--gui` select a region to screenshot
- `--full` full screen screenshot of every monitor
- `--screen` full screen screenshot

### Recording
 <small><strong>case: record</strong></small>
- `--abort` abort recording and the upload
- `--sound` snip with sound
- `--fullscreen` full screen without sound
- `--fullscreen-sound` fullscreen with sound
- `--gif` snip with gif output

### URL Shortener
<small><strong>case: shorten</strong></small>
- `--start` start the shortening service
- `--stop` stop the shortening service
- `--enable` enable the shortening service to start on boot
- `--disable` disable the shortening service from starting on boot
- `--logs` show the logs of the shortening service
> [!] SYSTEM-D is required to use this feature.

##### ★ When using Kooha, you'll not see some of these arguments as they aren't needed.

## Configuration

- `fps` will be your Max FPS
- `pixelformat` set the pixel format, default is `yuv420p`
- `encoder` set the encoder, default is `libx264`
- `preset` set the preset profile
- `wlscreenrec` set to true if want to use `wl-screenrec` (only for wl-roots based DEs and recommend for old GPUs/iGPUs)
- `bitrate` set the bitrate (only for `wl-screenrec`)
- `codec` set the codec, default is `hevc` (only for `wl-screenrec`)
- `extpixelformat` set the pixel format, default is `nv12` (only for `wl-screenrec`)
- `crf` set crf number
- `failsave` if your Video Recording upload fails, it will be saved on `~/Videos/e-zfailed`
- `colorworkaround` re-encode videos on upload for color correction, might take longer to upload
- `startnotif` show the start notification or not
- `endnotif` show the end notification or not
- `photosave` if true it will save screenshots in `photodir` will be ignored if using kooha
- `videosave` if true it will save videos in `videodir` will be ignored if using kooha
- `photodir` set the directory to save screenshots in there will be ignored if using kooha
- `videodir` set the directory to save videos in there will be ignored if using kooha
- `kooha_dir` set the kooha directory also save videos in here if using kooha
- `grimshot` set to true if want to use grimblast (hyprland only)
- `shortener_notif` show the shortening notification or not
##### ☆ When using Kooha, some of these arguments are unnecessary as they are not supported or required.

## Credits

The record script is based on [End's Dotfiles Record script](https://github.com/end-4/dots-hyprland/blob/main/.config/ags/scripts/record-script.sh) but to support alot more DEs, Configuration, allow GIF Output & so much more.

The grimshot Screenshot script has some functions borrowed from [Hyprland's grimblast](https://github.com/hyprwm/contrib/blob/main/grimblast/grimblast) to have freeze functionality.

> [!NOTE]
> If you wish to me to add your file host to support, you can open an issue on the GitHub repository but it will have semi-strict requirements and i'll not be adding every single file host out there (maybe unless if you do a PR).