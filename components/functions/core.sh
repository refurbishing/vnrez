SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/functions/variables.sh"

upload_video() {
	local file=$1
	local is_gif=$2
	upload_pid_file="$CONFIG_DIR/.upload_pid"

	if [[ ! -f "$file" ]]; then
		notify-send "Error: File not found: $file" -a "VNREZ Recorder"
		exit 1
	fi

	if [[ -f "$upload_pid_file" ]]; then
		rm "$upload_pid_file"
	fi

	if [[ "$service" == "none" ]]; then
		if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
			file_path=$(realpath "$file")
			echo -n "file://$file_path" | wl-copy -t text/uri-list
		else
			file_path=$(realpath "$file")
			echo -n "file://$file_path" | xclip -selection clipboard -t text/uri-list
		fi
		[[ "$endnotif" == true ]] && notify-send "Video copied to clipboard" -a "VNREZ Recorder"
		exit 0
	fi

	echo $$ >"$upload_pid_file"
	if [[ "$service" == "e-z" ]]; then
		http_code=$(curl -X POST -F "file=@${file}" -H "key: ${auth}" -w "%{http_code}" -o $response_video -s "${url}")
	elif [[ "$service" == "nest" ]]; then
		http_code=$(curl -X POST -F "file=@${file}" -H "Authorization: ${auth}" -w "%{http_code}" -o $response_video -s "${url}")
	fi

	if ! jq -e . >/dev/null 2>&1 <$response_video; then
		if [[ "$http_code" == "413" ]]; then
			notify-send "Recording too large." "Try a smaller recording or lower the settings." -a "VNREZ Recorder"
		else
			notify-send "Error occurred on upload." "Status Code: $http_code Please try again later." -a "VNREZ Recorder"
		fi
		rm $response_video
		[[ "$failsave" == true && "$1" != "--abort" && "$upload_mode" != true ]] && mkdir -p ~/Videos/failed && mv "$file" ~/Videos/failed/
		[[ "$is_gif" == "--gif" ]] && rm "$gif_pending_file"
		exit 1
	fi

	if [[ "$service" == "e-z" ]]; then
		success=$(jq -r ".success" <$response_video)
	elif [[ "$service" == "nest" ]]; then
		success=$(jq -r ".success" <$response_video)
		if [[ "$http_code" -eq 200 && "$success" == "null" ]]; then
			success="true"
		fi
	fi

	if [[ "$success" != "true" ]] || [[ "$success" == "null" ]]; then
		error=$(jq -r ".error" <$response_video)
		if [[ "$error" == "null" ]]; then
			if [[ "$http_code" == "413" ]]; then
				notify-send "Recording too large." "Try a smaller recording or lower the settings." -a "VNREZ Recorder"
			else
				notify-send "Error occurred on upload." "Status Code: $http_code Please try again later." -a "VNREZ Recorder"
			fi
		fi
		[[ "$failsave" == true && "$1" != "--abort" && "$upload_mode" != true ]] && mkdir -p ~/Videos/failed && mv "$file" ~/Videos/failed/
		[[ "$is_gif" == "--gif" ]] && rm "$gif_pending_file"
		rm $response_video
		if [[ -f "$upload_pid_file" ]]; then
			rm -f "$upload_pid_file"
		fi
		exit 1
	fi

	if [[ "$service" == "e-z" ]]; then
		file_url=$(jq -r ".imageUrl" <$response_video)
	elif [[ "$service" == "nest" ]]; then
		file_url=$(jq -r ".fileURL" <$response_video)
	fi

	if [[ "$file_url" != "null" ]]; then
		if [[ "$save" == true && "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
			echo $(date +%s) >"$(eval echo $kooha_last_time)"
		fi
		if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
			echo "$file_url" | xclip -selection clipboard
		else
			echo "$file_url" | wl-copy
		fi
		if [[ "$is_gif" == "--gif" || "$file" == *.gif ]]; then
			if [[ "$XDG_SESSION_TYPE" != "wayland" || ("$XDG_CURRENT_DESKTOP" != "GNOME" && "$XDG_CURRENT_DESKTOP" != "KDE") ]]; then
				[[ "$endnotif" == true ]] && notify-send "GIF URL copied to clipboard" -a "VNREZ Recorder" -i link
			fi
			[[ "$is_gif" == "--gif" && "$upload_mode" != true ]] && rm "$gif_pending_file"
		else
			if [[ "$XDG_SESSION_TYPE" != "wayland" || ("$XDG_CURRENT_DESKTOP" != "GNOME" && "$XDG_CURRENT_DESKTOP" != "KDE") ]]; then
				[[ "$endnotif" == true ]] && notify-send "Video URL copied to clipboard" -a "VNREZ Recorder" -i link
			fi
		fi
		if [[ "$save" == false && "$upload_mode" != true ]]; then
			rm "$file"
		fi
	else
		notify-send "Error: File URL is null. HTTP Code: $http_code" -a "VNREZ Recorder"
	fi
	if [[ "$upload_mode" != true ]]; then
		[[ -f $response_video ]] && rm $response_video
	fi
	if [[ -f "$upload_pid_file" ]]; then
		rm -f "$upload_pid_file"
	fi
}

upload_kooha() {
	if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
		last_upload_time=$(cat "$(eval echo $kooha_last_time)" 2>/dev/null || echo 0)
		new_files=$(find "$(eval echo $kooha_dir)" -type f -newer "$(eval echo $kooha_last_time)" | sort -n)

		if [[ -z "$new_files" ]]; then
			echo "INFO: No new recordings found."
			echo "NOTE: If you recorded something in Kooha before closing, and the recording doesn't try to upload,"
			echo "      then Kooha's directory location might be mismatched with the config's kooha directory."
		fi

		file_count=0
		for file_path in $new_files; do
			let file_count=file_count+1
			if [[ -f "$file_path" && -s "$file_path" ]]; then
				if [[ "$service" == "none" ]]; then
					file_count=0
					for file_path in $new_files; do
						let file_count=file_count+1
						echo -n "file://$(realpath "$file_path")" | wl-copy -t text/uri-list
						if [[ $(echo $new_files | wc -w) -gt 1 ]]; then
							[[ "$endnotif" == true ]] && notify-send "#$file_count Recording uploaded" "$file_count of $(echo $new_files | wc -w) URLs have been copied." -a "VNREZ Recorder"
						else
							if [[ "$service" == "none" ]]; then
								[[ "$endnotif" == true ]] && notify-send "Recording copied to clipboard" -a "VNREZ Recorder"
							fi
						fi
					done
					exit 0
				fi
			fi
			if [[ -f "$file_path" && -s "$file_path" ]]; then
				if [[ "$colorworkaround" == true && "${file_path##*.}" != "gif" ]]; then
					post_process_video "$file_path"
				fi

				if [[ -f "$file_path" ]]; then
					if [[ "$1" == "--gif" || "${file_path##*.}" == "gif" ]]; then
						gif_file=$(gif "$file_path")
						upload_video "$gif_file" "--gif"
					else
						upload_video "$file_path"
					fi

					if [[ $(echo $new_files | wc -w) -gt 1 ]]; then
						[[ "$endnotif" == true ]] && notify-send -i link "#$file_count Recording uploaded" "$file_count of $(echo $new_files | wc -w) URLs have been copied." -a "VNREZ Recorder"
					else
						if [[ "$service" == "none" ]]; then
							[[ "$endnotif" == true ]] && notify-send "Recording copied to clipboard" -a "VNREZ Recorder"
						fi
					fi
				else
					echo "Error: Encoded file not found: $file_path"
					notify-send "Error: Encoded file not found: $file_path" -a "VNREZ Recorder"
				fi
			fi

			if ((file_count % 2 == 0)); then
				sleep 2
			fi
		done

		if [[ $(echo $new_files | wc -w) -eq 1 ]]; then
			if [[ "$1" == "--gif" || "${file_path##*.}" == "gif" ]]; then
				notify-send -i link "GIF URL copied to clipboard" -a "VNREZ Recorder"
			else
				notify-send -i link "Video URL copied to clipboard" -a "VNREZ Recorder"
			fi
		fi

		rm "$(eval echo $kooha_last_time)"
	fi

	if [[ "$save" == false ]]; then
		recording_count=$(find "$(eval echo $kooha_dir)" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" -o -name "*.gif" \) | wc -l)
		if ((recording_count <= 1)); then
			rm -rf "$(eval echo $kooha_dir)"
		fi
	fi
}

abort_upload() {
	local check=false
	if [[ -f "$(eval echo $HOME/.config/vnrez/.upload_pid)" ]]; then
		upload_pid=$(cat "$(eval echo $HOME/.config/vnrez/.upload_pid)")
		if kill -0 "$upload_pid" 2>/dev/null; then
			pkill -P "$upload_pid"
			kill "$upload_pid"
			if [[ "$save" == false ]]; then
				if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
					new_files=$(find "$(eval echo $kooha_dir)" -type f -newer "$(eval echo $kooha_last_time)" | sort -n)
					file_count=$(echo "$new_files" | wc -l)
					if ((file_count > 0)); then
						for file_path in $new_files; do
							rm "$file_path"
						done
					fi
				else
					video_file=$(ls -t recording_*.mp4 | head -n 1)
					rm "$video_file"
					gif_file=$(ls -t recording_*.gif | head -n 1)
					if [[ -f "$gif_pending_file" ]]; then
						rm "$gif_file"
					fi
				fi
			fi
			rm "$(eval echo $HOME/.config/vnrez/.upload_pid)"
			if [[ "$service" == "none" ]]; then
				[[ "$endnotif" == true ]] && notify-send "Recording Aborted" "The Recording has been aborted." -a "VNREZ Recorder"
			else
				[[ "$endnotif" == true ]] && notify-send "Recording(s) Aborted" "The upload has been aborted." -a "VNREZ Recorder"
			fi
			check=true
		fi
	elif [[ -f "$(eval echo $HOME/.config/vnrez/.upload.lck)" ]]; then
		upload_lock_pid=$(cat "$(eval echo $HOME/.config/vnrez/.upload.lck)")
		if kill -0 "$upload_lock_pid" 2>/dev/null; then
			pkill -P "$upload_lock_pid"
			kill "$upload_lock_pid"
			if [[ -f "$(eval echo $HOME/.config/vnrez/.upload.lck)" ]]; then
				rm "$(eval echo $HOME/.config/vnrez/.upload.lck)"
			fi
			if [[ "$service" == "none" ]]; then
				[[ "$endnotif" == true ]] && notify-send "Recording Aborted" "The Recording has been aborted." -a "VNREZ Recorder"
			else
				[[ "$endnotif" == true ]] && notify-send "Recording(s) Aborted" "The upload has been aborted." -a "VNREZ Recorder"
			fi
			check=true
		fi
	elif [[ -f "$gif_pending_file" ]]; then
		if pgrep -f "ffmpeg" >/dev/null; then
			gif_pid=$(pgrep -f "ffmpeg")
			kill "$gif_pid"
			[[ -f "$gif_pending_file" ]] && rm "$gif_pending_file"
			check=true
		fi
	fi
	if [[ "$check" == false ]]; then
		notify-send "No Recording in Progress" "There is no recording to abort." -a "VNREZ Recorder"
		exit 0
	fi
}

upload_shot() {
	if [[ "$service" == "e-z" ]]; then
		upload_image=$(curl -X POST -F "file=@"$temp_file -H "key: "$auth -w "%{http_code}" -o $response -s "$url")
	elif [[ "$service" == "nest" ]]; then
		upload_image=$(curl -X POST -F "file=@"$temp_file -H "Authorization: "$auth -w "%{http_code}" -o $response -s "$url")
	fi

	if [[ "$service" == "e-z" ]]; then
		success=$(cat /tmp/upload.json | jq -r ".success")
		if [[ "$success" != "true" ]] || [[ "$success" == "null" ]]; then
			error=$(cat /tmp/upload.json | jq -r ".error")
			if [[ "$error" == "null" ]]; then
				notify-send "Error occurred while uploading. Try again later." -a "Flameshot"
				rm $temp_file
				exit 1
			else
				notify-send "Error: $error" -a "Flameshot"
				rm $temp_file
				exit 1
			fi
		fi
	fi

	if [[ ! "$service" == "e-z" ]]; then
		if ! jq -e . >/dev/null 2>&1 <$response; then
			notify-send "Error occurred while uploading. Try again later." -a "Flameshot"
			rm $temp_file
			exit 1
		fi
	fi

	http_code="${upload_image: -3}"

	if [[ "$http_code" -ne 200 ]]; then
		error_message=$(cat $response | jq -r .error)
		if [[ "$error_message" == "null" ]]; then
			if [[ "$service" == "e-z" || "$service" == "nest" ]]; then
				notify-send "Error occurred while uploading. Try again later." -a "Flameshot"
			fi
		else
			notify-send "$error_message" -a "Flameshot"
		fi
		rm $temp_file
		exit 1
	else
		if [[ "$service" == "e-z" ]]; then
			image_url=$(cat $response | jq -r .imageUrl)
		elif [[ "$service" == "nest" ]]; then
			image_url=$(cat $response | jq -r .fileURL)
		fi
		if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
			echo $image_url | wl-copy
		else
			echo $image_url | xclip -sel c
		fi
		notify-send "Image URL copied to clipboard" -a "Flameshot" -i $temp_file
	fi
}

post_process_video() {
	local input_file=$1
	local output_file="${input_file%.mp4}_processed.mp4"
	ffmpeg -i "$input_file" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,format=$pixelformat" -colorspace bt709 -color_primaries bt709 -color_trc bt709 -c:v $encoder -preset $preset -crf $crf -movflags +faststart -c:a copy "$output_file"
	mv "$output_file" "$input_file"
}

