#!/bin/bash -e
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/functions/variables.sh"
source "$SCRIPT_DIR/functions/checks.sh"
source "$SCRIPT_DIR/functions/misc.sh"
source "$SCRIPT_DIR/functions/core.sh"

if [ -f "$CONFIG_FILE" ]; then
	source "$CONFIG_FILE"
fi

check_dependencies
check_root

if [[ "$1" != "auto" && -f "$CONFIG_FILE" ]]; then
	check_variables
fi

if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
	service="none"
	pixelformat="yuv420p"
	save=false
	encoder="libx264"
	fps=60
	crf=20
	preset=fast
	shift
fi

getdate() {
	date '+%Y-%m-%d_%H.%M.%S'
}
getaudiooutput() {
	pactl list sources | grep 'Name' | grep 'monitor' | cut -d ' ' -f2
}

wait_for_file() {
    local file="$1"
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if [ -f "$file" ] && [ -s "$file" ]; then
            sleep 0.5
            return 0
        fi
        sleep 0.5
        attempt=$((attempt + 1))
    done
    return 1
}

gif() {
	local video_file=$1
	local gif_file="${video_file%.mp4}.gif"
	ffmpeg -i "$video_file" -vf "fps=40,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" -c:v gif "$gif_file"
	rm "$video_file"
	echo "$gif_file"
}

if [[ "$videosave" == true && ! ("$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon")) ]]; then
	mkdir -p "$(eval echo $directory)"
	cd "$(eval echo $directory)" || exit
else
	if [[ "$service" == none ]]; then
		if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
			if [[ "$1" == "auto" ]]; then
				find "$(eval echo $kooha_dir)" -maxdepth 0 -type d -ctime +1 -exec rm -rf {} \; >/dev/null 2>&1
			fi
		else
			mkdir -p /tmp/temp
			find /tmp/temp -maxdepth 0 -type d -ctime +1 -exec rm -rf {} \; >/dev/null 2>&1
		fi
		mkdir -p /tmp/temp
		cd /tmp/temp || exit
	else
		cd /tmp || exit
	fi
fi

if [[ "$1" == "--abort" || ( "$1" == "auto" && "$2" == "--abort" ) ]]; then
	if [[ "$upload_mode" == true ]]; then
		abort_upload
	fi
	if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
		if pgrep ffmpeg >/dev/null; then
			[[ "$endnotif" == true ]] && notify-send "Recording Aborted" "The upload has been aborted." -a "VNREZ Recorder"
			pkill ffmpeg
			if [[ -f "$gif_pending_file" ]]; then
				rm "$gif_pending_file"
			fi
			if [[ "$videosave" == false ]]; then
				video_file=$(ls -t recording_*.mp4 | head -n 1)
				rm "$video_file"
			fi
			exit 0
		else
			abort_upload
		fi
	else
		if pgrep wf-recorder >/dev/null; then
			[[ "$endnotif" == true ]] && notify-send "Recording Aborted" "The upload has been aborted." -a "VNREZ Recorder"
			pkill wf-recorder
			if [[ -f "$gif_pending_file" ]]; then
				rm "$gif_pending_file"
			fi
			if [[ "$videosave" == false ]]; then
				video_file=$(ls -t recording_*.mp4 | head -n 1)
				rm "$video_file"
			fi
			exit 0
		elif pgrep wl-screenrec >/dev/null; then
			[[ "$endnotif" == true ]] && notify-send "Recording Aborted" "The upload has been aborted." -a "VNREZ Recorder"
			pkill wl-screenrec
			if [[ -f "$gif_pending_file" ]]; then
				rm "$gif_pending_file"
			fi
			if [[ "$videosave" == false ]]; then
				video_file=$(ls -t recording_*.mp4 | head -n 1)
				rm "$video_file"
			fi
			exit 0
		elif pgrep kooha >/dev/null; then
			[[ "$endnotif" == true ]] && notify-send "Recording Aborted" "The upload has been aborted." -a "VNREZ Recorder"
			parent_pid=$(pgrep -f "kooha" | xargs -I {} ps -o ppid= -p {})
			if [[ -n "$parent_pid" ]]; then
				if [[ -d "$(eval echo $kooha_dir)" ]]; then
					if [[ -f "$(eval echo $kooha_last_time)" ]]; then
						read_kooha_last_time=$(cat "$(eval echo $kooha_last_time)")
						find "$(eval echo $kooha_dir)" -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" \) -newer "$read_kooha_last_time" -exec rm {} \;
						rm "$(eval echo $kooha_last_time)"
					fi
				fi
				killall kooha && kill -KILL "$parent_pid"
			fi
			exit 0
		else
			abort_upload
		fi
	fi
fi

if [[ -z "$1" || "$1" == "--sound" || "$1" == "--fullscreen-sound" || "$1" == "--fullscreen" || "$1" == "--gif" || "$1" == "--no-sound" || ( "$1" == "auto" && ( -z "$2" || "$2" == "--sound" || "$2" == "--fullscreen-sound" || "$2" == "--fullscreen" || "$2" == "--gif" || "$2" == "--no-sound" )) ]]; then
	if [[ "$1" == "--sound" || "$1" == "--fullscreen-sound" || "$1" == "--fullscreen" || "$1" == "--no-sound" || ( "$1" == "auto" && ( "$2" == "--sound" || "$2" == "--fullscreen-sound" || "$2" == "--fullscreen" || "$2" == "--no-sound" )) ]]; then
		if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
			printf "\e[30m\e[46m$1\e[0m"
			printf "\e[1;32m is only for X11 or wlroots Compositors as its not needed. \e[0m\n"
			notify-send "This Argument is only for X11 or wlroots Compositors" "As its not needed." -a "VNREZ Recorder"
			sleep 2
			exit 1
		fi
	fi
else
	if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
		echo "Invalid argument: $1"
		notify-send "Invalid argument: $1" -a "VNREZ Recorder"
		exit 1
	fi
fi

if [[ "$1" == "--gif" || ( "$1" == "auto" && "$2" == "--gif" ) ]]; then
	touch "$gif_pending_file"
fi

get_recorder_command() {
	if [[ "$1" == "auto" ]]; then
		echo "wf-recorder"
	elif [[ "$wlscreenrec" == true ]]; then
		echo "wl-screenrec"
	else
		echo "wf-recorder"
	fi
}

if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
	if pgrep -x "kooha" >/dev/null; then
		echo "Kooha is already running."
		echo "For the Videos to Upload, Simply just Close the Window."
		notify-send "Kooha is already running." -a "VNREZ Recorder"
		exit 1
	fi
	echo $(date +%s) >"$(eval echo $kooha_last_time)"
	mkdir -p "$(eval echo $kooha_dir)"
	if command -v kooha &> /dev/null; then
		kooha &
	else
		flatpak run io.github.seadve.Kooha &
	fi
	kooha_pid=$!
	wait $kooha_pid
	upload_kooha
else
	if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
		if pgrep ffmpeg >/dev/null; then
			if [[ -f "$gif_pending_file" || "$1" == "--gif" || ( "$1" == "auto" && "$2" == "--gif" ) ]]; then
				[[ "$endnotif" == true ]] && notify-send -t 5000 "Recording is being converted to GIF" "Please Wait.." -a "VNREZ Recorder" &
				pkill ffmpeg &
				wait
				[[ "$colorworkaround" == true ]] && post_process_video "$video_file"
				video_file=$(ls -t recording_*.mp4 | head -n 1)
				if wait_for_file "$video_file"; then
					gif_file=$(gif "$video_file")
					upload_video "$gif_file" "--gif"
				else
					notify-send "Error: Recording file not ready" "Failed to access the recording file." -a "VNREZ Recorder"
					exit 1
				fi
			else
				[[ "$endnotif" == true ]] && notify-send -t 2000 "Recording Stopped" "Stopped" -a "VNREZ Recorder" &
				pkill ffmpeg &
				wait
				video_file=$(ls -t recording_*.mp4 | head -n 1)
				if wait_for_file "$video_file"; then
					[[ "$colorworkaround" == true ]] && post_process_video "$video_file"
					upload_video "$video_file"
				else
					notify-send "Error: Recording file not ready" "Failed to access the recording file." -a "VNREZ Recorder"
					exit 1
				fi
			fi
		else
			if [[ "$1" == "--sound" || ( "$1" == "auto" && "$2" == "--sound" ) ]]; then
				[[ "$startnotif" == true ]] && notify-send "Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
				region=$(slop -f "%x,%y %w,%h")
				if [[ -z "$region" ]]; then
					notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
					exit 1
				fi
				IFS=', ' read -r x y width height <<<"$region"
				ffmpeg -video_size "${width}x${height}" -framerate $fps -f x11grab -i $DISPLAY+"${x},${y}" -f pulse -i "$(getaudiooutput)" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v $encoder -preset $preset -crf $crf -pix_fmt $pixelformat -movflags +faststart -c:a aac -b:a 128k './recording_'"$(getdate)"'.mp4' &
				disown
			elif [[ "$1" == "--fullscreen-sound" || ( "$1" == "auto" && "$2" == "--fullscreen-sound" ) ]]; then
				if [[ "$videosave" == true ]]; then
					[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'recording_'"$(getdate)"'.mp4' -a "VNREZ Recorder"
				else
					[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'Started' -a "VNREZ Recorder"
				fi
				ffmpeg -video_size $(getactivemonitor) -framerate $fps -f x11grab -i $DISPLAY -f pulse -i "$(getaudiooutput)" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v $encoder -preset $preset -crf $crf -pix_fmt $pixelformat -movflags +faststart -c:a aac -b:a 128k './recording_'"$(getdate)"'.mp4' &
				disown
			elif [[ "$1" == "--fullscreen" || ( "$1" == "auto" && "$2" == "--fullscreen" ) ]]; then
				if [[ "$videosave" == true ]]; then
					[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'recording_'"$(getdate)"'.mp4' -a "VNREZ Recorder"
				else
					[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'Started' -a "VNREZ Recorder"
				fi
				ffmpeg -video_size $(getactivemonitor) -framerate $fps -f x11grab -i $DISPLAY -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v $encoder -preset $preset -crf $crf -pix_fmt $pixelformat -movflags +faststart './recording_'"$(getdate)"'.mp4' &
				disown
			elif [[ "$1" == "--gif" || ( "$1" == "auto" && "$2" == "--gif" ) ]]; then
				touch "$gif_pending_file"
				[[ "$startnotif" == true ]] && notify-send "GIF Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
				region=$(slop -f "%x,%y %w,%h")
				if [[ -z "$region" ]]; then
					notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
					exit 1
				fi
				IFS=', ' read -r x y width height <<<"$region"
				ffmpeg -video_size "${width}x${height}" -framerate $fps -f x11grab -i $DISPLAY+"${x},${y}" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v $encoder -preset $preset -crf $crf -pix_fmt $pixelformat -movflags +faststart './recording_'"$(getdate)"'.mp4' &
				disown
			else
				[[ "$startnotif" == true ]] && notify-send "Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
				region=$(slop -f "%x,%y %w,%h")
				if [[ -z "$region" ]]; then
					notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
					exit 1
				fi
				IFS=', ' read -r x y width height <<<"$region"
				ffmpeg -video_size "${width}x${height}" -framerate $fps -f x11grab -i $DISPLAY+"${x},${y}" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v $encoder -preset $preset -crf $crf -pix_fmt $pixelformat -movflags +faststart './recording_'"$(getdate)"'.mp4' &
				disown
			fi
		fi
	else
		recorder_command=$(get_recorder_command)
		if pgrep "$recorder_command" >/dev/null; then
			if [[ -f "$gif_pending_file" || "$1" == "--gif" || ( "$1" == "auto" && "$2" == "--gif" ) ]]; then
				[[ "$endnotif" == true ]] && notify-send -t 5000 "Recording is being converted to GIF" "Please Wait.." -a "VNREZ Recorder" &
				pkill "$recorder_command" &
				wait
				video_file=$(ls -t recording_*.mp4 | head -n 1)
				if wait_for_file "$video_file"; then
					[[ "$colorworkaround" == true ]] && post_process_video "$video_file"
					gif_file=$(gif "$video_file")
					upload_video "$gif_file" "--gif"
				else
					notify-send "Error: Recording file not ready" "Failed to access the recording file." -a "VNREZ Recorder"
					exit 1
				fi
			else
				if [[ -z "$1" || "$1" == "--no-sound" || ( "$1" == "auto" && ( -z "$2" || "$2" == "--no-sound" )) ]]; then
					[[ "$endnotif" == true ]] && notify-send -t 2000 "Recording Stopped" "Stopped" -a "VNREZ Recorder" &
					pkill "$recorder_command" &
					wait
					video_file=$(ls -t recording_*.mp4 | head -n 1)
					if wait_for_file "$video_file"; then
						[[ "$colorworkaround" == true ]] && post_process_video "$video_file"
						upload_video "$video_file"
					else
						notify-send "Error: Recording file not ready" "Failed to access the recording file." -a "VNREZ Recorder"
						exit 1
					fi
				fi
			fi
		else
			if [[ "$wlscreenrec" == true ]]; then
				if [[ "$1" == "--sound" || ( "$1" == "auto" && "$2" == "--sound" ) ]]; then
					[[ "$startnotif" == true ]] && notify-send "Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
					region=$(slurp)
					if [[ -z "$region" ]]; then
						notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
						exit 1
					fi
					if [[ "$extpixelformat" != "auto" ]]; then
						wl-screenrec --geometry "$region" --audio --audio-device "$(getaudiooutput)" --encode-pixfmt "$extpixelformat" -f "./recording_$(getdate).mp4" &
					else
						wl-screenrec --geometry "$region" --audio --audio-device "$(getaudiooutput)" -f "./recording_$(getdate).mp4" &
					fi
					disown
				elif [[ "$1" == "--fullscreen-sound" || ( "$1" == "auto" && "$2" == "--fullscreen-sound" ) ]]; then
					if [[ "$videosave" == true ]]; then
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'recording_'"$(getdate)"'.mp4' -a "VNREZ Recorder"
					else
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'Started' -a "VNREZ Recorder"
					fi
					command="$recorder_command --output $(getactivemonitor) --audio --audio-device \"$(getaudiooutput)\""
					if [[ "$extpixelformat" != "auto" ]]; then
						command+=" --encode-pixfmt \"$extpixelformat\""
					fi
					command+=" -f './recording_'"$(getdate)"'.mp4'"
					eval "$command" &
					disown
				elif [[ "$1" == "--fullscreen" || ( "$1" == "auto" && "$2" == "--fullscreen" ) ]]; then
					if [[ "$videosave" == true ]]; then
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'recording_'"$(getdate)"'.mp4' -a "VNREZ Recorder"
					else
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'Started' -a "VNREZ Recorder"
					fi
					command="$recorder_command --output $(getactivemonitor)"
					if [[ "$extpixelformat" != "auto" ]]; then
						command+=" --encode-pixfmt \"$extpixelformat\""
					fi
					command+=" -f './recording_'"$(getdate)"'.mp4'"
					eval "$command" &
					disown
				elif [[ "$1" == "--gif" || ( "$1" == "auto" && "$2" == "--gif" ) ]]; then
					touch "$gif_pending_file"
					[[ "$startnotif" == true ]] && notify-send "GIF Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
					region=$(slurp)
					if [[ -z "$region" ]]; then
						notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
						exit 1
					fi
					command="$recorder_command --geometry \"$region\""
					if [[ "$extpixelformat" != "auto" ]]; then
						command+=" --encode-pixfmt \"$extpixelformat\""
					fi
					command+=" -f './recording_'"$(getdate)"'.mp4'"
					eval "$command" &
					disown
				else
					[[ "$startnotif" == true ]] && notify-send "Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
					region=$(slurp)
					if [[ -z "$region" ]]; then
						notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
						exit 1
					fi
					command="$recorder_command --geometry \"$region\""
					if [[ "$extpixelformat" != "auto" ]]; then
						command+=" --encode-pixfmt \"$extpixelformat\""
					fi
					command+=" -f './recording_'"$(getdate)"'.mp4'"
					eval "$command" &
					disown
				fi
			else
				if [[ "$1" == "--sound" || ( "$1" == "auto" && "$2" == "--sound" ) ]]; then
					[[ "$startnotif" == true ]] && notify-send "Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
					region=$(slurp)
					if [[ -z "$region" ]]; then
						notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
						exit 1
					fi
					"$recorder_command" --pixel-format $pixelformat -c "$encoder" -p preset=$preset -p crf=$crf -f './recording_'"$(getdate)"'.mp4' --geometry "$region" --audio="$(getaudiooutput)" -r $fps &
					disown
				elif [[ "$1" == "--fullscreen-sound" || ( "$1" == "auto" && "$2" == "--fullscreen-sound" ) ]]; then
					if [[ "$videosave" == true ]]; then
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'recording_'"$(getdate)"'.mp4' -a "VNREZ Recorder"
					else
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'Started' -a "VNREZ Recorder"
					fi
					"$recorder_command" -o $(getactivemonitor) --pixel-format $pixelformat -c "$encoder" -p preset=$preset -p crf=$crf -f './recording_'"$(getdate)"'.mp4' --audio="$(getaudiooutput)" -r $fps &
					disown
				elif [[ "$1" == "--fullscreen" || ( "$1" == "auto" && "$2" == "--fullscreen" ) ]]; then
					if [[ "$videosave" == true ]]; then
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'recording_'"$(getdate)"'.mp4' -a "VNREZ Recorder"
					else
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'Started' -a "VNREZ Recorder"
					fi
					"$recorder_command" -o $(getactivemonitor) --pixel-format $pixelformat -c "$encoder" -p preset=$preset -p crf=$crf -f './recording_'"$(getdate)"'.mp4' -r $fps &
					disown
				elif [[ "$1" == "--gif" || ( "$1" == "auto" && "$2" == "--gif" ) ]]; then
					touch "$gif_pending_file"
					[[ "$startnotif" == true ]] && notify-send "GIF Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
					region=$(slurp)
					if [[ -z "$region" ]]; then
						notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
						exit 1
					fi
					"$recorder_command" --pixel-format $pixelformat -c "$encoder" -p preset=$preset -p crf=$crf -f './recording_'"$(getdate)"'.mp4' --geometry "$region" -r $fps &
					disown
				else
					if [[ -z "$1" || "$1" == "--no-sound" || ( "$1" == "auto" && ( -z "$2" || "$2" == "--no-sound" )) ]]; then
						[[ "$startnotif" == true ]] && notify-send "Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
						region=$(slurp)
						if [[ -z "$region" ]]; then
							notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
							exit 1
						fi
						"$recorder_command" --pixel-format $pixelformat -c "$encoder" -p preset=$preset -p crf=$crf -f './recording_'"$(getdate)"'.mp4' --geometry "$region" -r $fps &
						disown
					fi
				fi
			fi
		fi
	fi
fi

exit 0
