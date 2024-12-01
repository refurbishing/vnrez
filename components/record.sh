#!/bin/bash -e
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/functions/variables.sh"
source "$SCRIPT_DIR/functions/checks.sh"
source "$SCRIPT_DIR/functions/misc.sh"
source "$SCRIPT_DIR/functions/core.sh"

check_dependencies
check_root
check_variables

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
	help
fi

getdate() {
	date '+%Y-%m-%d_%H.%M.%S'
}
getaudiooutput() {
	pactl list sources | grep 'Name' | grep 'monitor' | cut -d ' ' -f2
}
getactivemonitor() {
	if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
		active_monitor=$(xdpyinfo | grep dimensions | awk '{print $2}')
	elif [[ "$XDG_SESSION_TYPE" == "wayland" && "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
		active_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
	else
		active_monitor=$(wlr-randr --json | jq -r '.[] | select(.enabled == true) | .name')
	fi
	echo "$active_monitor"
}

gif() {
	local video_file=$1
	local gif_file="${video_file%.mp4}.gif"
	ffmpeg -i "$video_file" -vf "fps=40,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" -c:v gif "$gif_file"
	rm "$video_file"
	echo "$gif_file"
}

if [[ "$save" == true && ! ("$XDG_SESSION_TYPE" == "wayland" &&
	("$XDG_CURRENT_DESKTOP" == "GNOME" ||
	"$XDG_CURRENT_DESKTOP" == "KDE" ||
	"$XDG_CURRENT_DESKTOP" == "COSMIC")) ]]; then
	mkdir -p "$(eval echo $directory)"
	cd "$(eval echo $directory)" || exit
else
	if [[ "$service" == none ]]; then
		find /tmp/temp -maxdepth 0 -type d -ctime +1 -exec rm -rf {} \;
		mkdir -p /tmp/temp
		cd /tmp/temp || exit
	else
		cd /tmp || exit
	fi
fi

if [[ "$1" == "--abort" ]]; then
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
			if [[ "$save" == false ]]; then
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
			if [[ "$save" == false ]]; then
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
			if [[ "$save" == false ]]; then
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

if [[ -z "$1" || "$1" == "--sound" || "$1" == "--fullscreen-sound" || "$1" == "--fullscreen" || "$1" == "--gif" || "$1" == "--no-sound" ]]; then
	if [[ "$1" == "--sound" || "$1" == "--fullscreen-sound" || "$1" == "--fullscreen" || "$1" == "--no-sound" ]]; then
		if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC") ]]; then
			printf "\e[30m\e[46m$1\e[0m"
			printf "\e[1;32m is only for X11 or wlroots Compositors as its not needed. \e[0m\n"
			notify-send "This Argument is only for X11 or wlroots Compositors" "As its not needed." -a "VNREZ Recorder"
			sleep 2
			exit 1
		fi
	fi
else
	if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC") ]]; then
		echo "Invalid argument: $1"
		notify-send "Invalid argument: $1" -a "VNREZ Recorder"
		exit 1
	fi
fi

if [[ "$1" == "--gif" ]]; then
	touch "$gif_pending_file"
fi

get_recorder_command() {
	if [[ "$wlscreenrec" == true ]]; then
		echo "wl-screenrec"
	else
		echo "wf-recorder"
	fi
}

if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC") ]]; then
	if pgrep -x "kooha" >/dev/null; then
		echo "Kooha is already running."
		echo "For the Videos to Upload, Simply just Close the Window."
		notify-send "Kooha is already running." -a "VNREZ Recorder"
		exit 1
	fi
	echo $(date +%s) >"$(eval echo $kooha_last_time)"
	mkdir -p "$(eval echo $kooha_dir)"
	kooha &
	kooha_pid=$!
	wait $kooha_pid
	upload_kooha
else
	if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
		if pgrep ffmpeg >/dev/null; then
			if [[ -f "$gif_pending_file" || "$1" == "--gif" ]]; then
				[[ "$endnotif" == true ]] && notify-send -t 5000 "Recording is being converted to GIF" "Please Wait.." -a "VNREZ Recorder" &
				pkill ffmpeg &
				wait
				sleep 1.5
				video_file=$(ls -t recording_*.mp4 | head -n 1)
				gif_file=$(gif "$video_file")
				upload_video "$gif_file" "--gif"
			else
				[[ "$endnotif" == true ]] && notify-send -t 2000 "Recording Stopped" "Stopped" -a "VNREZ Recorder" &
				pkill ffmpeg &
				wait
				sleep 1.5
				video_file=$(ls -t recording_*.mp4 | head -n 1)
				upload_video "$video_file"
			fi
		else
			if [[ "$1" == "--sound" ]]; then
				[[ "$startnotif" == true ]] && notify-send "Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
				region=$(slop -f "%x,%y %w,%h")
				if [[ -z "$region" ]]; then
					notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
					exit 1
				fi
				IFS=', ' read -r x y width height <<<"$region"
				ffmpeg -video_size "${width}x${height}" -framerate $fps -f x11grab -i $DISPLAY+"${x},${y}" -f pulse -i "$(getaudiooutput)" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v $encoder -preset $preset -crf $crf -pix_fmt $pixelformat -movflags +faststart -c:a aac -b:a 128k './recording_'"$(getdate)"'.mp4' &
				disown
			elif [[ "$1" == "--fullscreen-sound" ]]; then
				if [[ "$save" == true ]]; then
					[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'recording_'"$(getdate)"'.mp4' -a "VNREZ Recorder"
				else
					[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'Started' -a "VNREZ Recorder"
				fi
				ffmpeg -video_size $(getactivemonitor) -framerate $fps -f x11grab -i $DISPLAY -f pulse -i "$(getaudiooutput)" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v $encoder -preset $preset -crf $crf -pix_fmt $pixelformat -movflags +faststart -c:a aac -b:a 128k './recording_'"$(getdate)"'.mp4' &
				disown
			elif [[ "$1" == "--fullscreen" ]]; then
				if [[ "$save" == true ]]; then
					[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'recording_'"$(getdate)"'.mp4' -a "VNREZ Recorder"
				else
					[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'Started' -a "VNREZ Recorder"
				fi
				ffmpeg -video_size $(getactivemonitor) -framerate $fps -f x11grab -i $DISPLAY -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v $encoder -preset $preset -crf $crf -pix_fmt $pixelformat -movflags +faststart './recording_'"$(getdate)"'.mp4' &
				disown
			elif [[ "$1" == "--gif" ]]; then
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
			if [[ -f "$gif_pending_file" || "$1" == "--gif" ]]; then
				[[ "$endnotif" == true ]] && notify-send -t 5000 "Recording is being converted to GIF" "Please Wait.." -a "VNREZ Recorder" &
				pkill "$recorder_command" &
				wait
				sleep 1.5
				video_file=$(ls -t recording_*.mp4 | head -n 1)
				gif_file=$(gif "$video_file")
				upload_video "$gif_file" "--gif"
			else
				if [[ -z "$1" || "$1" == "--no-sound" ]]; then
					[[ "$endnotif" == true ]] && notify-send -t 2000 "Recording Stopped" "Stopped" -a "VNREZ Recorder" &
					pkill "$recorder_command" &
					wait
					sleep 1.5
					video_file=$(ls -t recording_*.mp4 | head -n 1)
					[[ "$colorworkaround" == true ]] && post_process_video "$video_file"
					upload_video "$video_file"
				fi
			fi
		else
			if [[ "$wlscreenrec" == true ]]; then
				if [[ "$1" == "--sound" ]]; then
					[[ "$startnotif" == true ]] && notify-send "Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
					region=$(slurp)
					if [[ -z "$region" ]]; then
						notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
						exit 1
					fi
					command="$recorder_command --geometry \"$region\" --audio --audio-device \"$(getaudiooutput)\""
					if [[ "$extpixelformat" != "auto" ]]; then
						command+=" --encode-pixfmt \"$extpixelformat\""
					fi
					command+=" -f './recording_'"$(getdate)"'.mp4'"
					eval "$command" &
					disown
				elif [[ "$1" == "--fullscreen-sound" ]]; then
					if [[ "$save" == true ]]; then
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
				elif [[ "$1" == "--fullscreen" ]]; then
					if [[ "$save" == true ]]; then
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
				elif [[ "$1" == "--gif" ]]; then
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
				if [[ "$1" == "--sound" ]]; then
					[[ "$startnotif" == true ]] && notify-send "Screen Snip Recording" "Select the region to Start" -a "VNREZ Recorder"
					region=$(slurp)
					if [[ -z "$region" ]]; then
						notify-send "Recording Canceling" 'Canceled' -a "VNREZ Recorder"
						exit 1
					fi
					"$recorder_command" --pixel-format $pixelformat -c "$encoder" -p preset=$preset -p crf=$crf -f './recording_'"$(getdate)"'.mp4' --geometry "$region" --audio="$(getaudiooutput)" -r $fps &
					disown
				elif [[ "$1" == "--fullscreen-sound" ]]; then
					if [[ "$save" == true ]]; then
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'recording_'"$(getdate)"'.mp4' -a "VNREZ Recorder"
					else
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'Started' -a "VNREZ Recorder"
					fi
					"$recorder_command" -o $(getactivemonitor) --pixel-format $pixelformat -c "$encoder" -p preset=$preset -p crf=$crf -f './recording_'"$(getdate)"'.mp4' --audio="$(getaudiooutput)" -r $fps &
					disown
				elif [[ "$1" == "--fullscreen" ]]; then
					if [[ "$save" == true ]]; then
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'recording_'"$(getdate)"'.mp4' -a "VNREZ Recorder"
					else
						[[ "$startnotif" == true ]] && notify-send "Starting Recording" 'Started' -a "VNREZ Recorder"
					fi
					"$recorder_command" -o $(getactivemonitor) --pixel-format $pixelformat -c "$encoder" -p preset=$preset -p crf=$crf -f './recording_'"$(getdate)"'.mp4' -r $fps &
					disown
				elif [[ "$1" == "--gif" ]]; then
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
					if [[ -z "$1" || "$1" == "--no-sound" ]]; then
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
