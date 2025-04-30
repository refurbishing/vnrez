SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/functions/variables.sh"
source "$SCRIPT_DIR/functions/misc.sh"

upload_video() {
	local file=$1
	local is_gif=$2

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
	elif [[ "$service" == "emogirls" ]]; then
		http_code=$(curl -X POST -F "file=@${file}" -H "X-API-Key: ${auth}" -w "%{http_code}" -o $response_video -s "${url}")
	else
		if [[ -f "$CONFIG_DIR/services/${service}" ]]; then
			source "$CONFIG_DIR/services/${service}"
			http_code=$(curl -X POST -F "${file_form_name}=@${file}" -H "${auth_header}: ${auth_token}" -w "%{http_code}" -o $response_video -s "${request_url}")
		else
			notify-send "Error: Custom service '$service' not found" -a "VNREZ Recorder"
			exit 1
		fi
	fi

	if ! jq -e . >/dev/null 2>&1 <$response_video; then
		if [[ "$http_code" == "413" ]]; then
			notify-send "Recording too large." "Try a smaller recording or lower the settings." -a "VNREZ Recorder"
		else
			notify-send "Error occurred on upload." "Status Code: $http_code Please try again later." -a "VNREZ Recorder"
		fi
		rm $response_video
		
		if [[ "$failsave" == true && "$1" != "--abort" && "$upload_mode" != true ]]; then
			mkdir -p "$(eval echo $videodir)/failed" 2>/dev/null
			cp "$file" "$(eval echo $videodir)/failed/"
		fi
		
		[[ "$is_gif" == "--gif" ]] && rm "$gif_pending_file"
		[[ -f "$upload_pid_file" ]] && rm -f "$upload_pid_file"
		exit 1
	fi

	if [[ "$service" == "e-z" ]]; then
		success=$(jq -r ".success" <$response_video)
	elif [[ "$service" == "emogirls" ]]; then
		if [[ "$http_code" -eq 200 && "$success" == "null" ]]; then
			success="true"
		elif [[ "$http_code" -eq 400 && "$success" == "null" ]]; then
			success="false"
		fi
	elif [[ "$service" == "nest" ]]; then
		success=$(jq -r ".success" <$response_video)
		if [[ "$http_code" -eq 200 && "$success" == "null" ]]; then
			success="true"
		fi
	else
		if [[ -f "$CONFIG_DIR/services/${service}" ]]; then
			source "$CONFIG_DIR/services/${service}"
			if [[ -n "$error_json_path" ]]; then
				error=$(jq -r ".$error_json_path" <$response_video)
				if [[ "$error" != "null" ]]; then
					success="false"
				else
					success="true"
				fi
			else
				success="true"
			fi
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
		
		if [[ "$failsave" == true && "$1" != "--abort" && "$upload_mode" != true ]]; then
			mkdir -p "$(eval echo $videodir)/failed" 2>/dev/null
			cp "$file" "$(eval echo $videodir)/failed/"
		fi
		
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
	elif [[ "$service" == "emogirls" ]]; then
		file_url=$(jq -r ".url" <$response_video)
	else
		if [[ -f "$CONFIG_DIR/services/${service}" ]]; then
			source "$CONFIG_DIR/services/${service}"
			file_url=$(jq -r ".$url_json_path" <$response_video)
		fi
	fi

	if [[ "$file_url" != "null" ]]; then
		if [[ "$videosave" == true && "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC" || "$XDG_CURRENT_DESKTOP" == "X-Cinnamon") ]]; then
			echo $(date +%s) >"$(eval echo $kooha_last_time)"
		fi
		if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
			echo "$file_url" | xclip -selection clipboard
		else
			echo "$file_url" | wl-copy
		fi
			if [[ "$videosave" == true && "$upload_mode" != true ]]; then
			mkdir -p "$(eval echo $videodir)" 2>/dev/null
			filename=$(basename "$file")
			cp "$file" "$(eval echo $videodir)/$filename"
			notify-send "Recording saved" "$(eval echo $videodir)/" -a "VNREZ Recorder"
		fi
		
		if [[ "$is_gif" == "--gif" || "$file" == *.gif ]]; then
			if [[ "$XDG_SESSION_TYPE" != "wayland" || ("$XDG_CURRENT_DESKTOP" != "GNOME" && "$XDG_CURRENT_DESKTOP" != "KDE") ]]; then
				[[ "$endnotif" == true ]] && notify-send "GIF URL copied to clipboard" -a "VNREZ Recorder" -i link
			fi
			[[ "$is_gif" == "--gif" && "$upload_mode" != true ]] && rm "$gif_pending_file"
		else
			if [[ "$XDG_SESSION_TYPE" != "wayland" || ("$XDG_CURRENT_DESKTOP" != "GNOME" && "$XDG_CURRENT_DESKTOP" != "KDE") ]]; then
				if [[ "$upload_mode" == true ]]; then
					[[ "$endnotif" == true ]] && notify-send "URL copied to clipboard" -a "VNREZ Recorder" -i link
				else
					[[ "$endnotif" == true ]] && notify-send "Video URL copied to clipboard" -a "VNREZ Recorder" -i link
				fi
			fi
		fi
			if [[ "$videosave" != true && "$upload_mode" != true ]]; then
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
	if [[ -f "$upload_pid_file" ]]; then
		upload_pid=$(cat "$upload_pid_file")
		if kill -0 "$upload_pid" 2>/dev/null; then
			pkill -P "$upload_pid"
			kill "$upload_pid"
			if [[ "$videosave" != true ]]; then
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
			rm "$upload_pid_file"
			if [[ "$service" == "none" ]]; then
				[[ "$endnotif" == true ]] && notify-send "Recording Aborted" "The Recording has been aborted." -a "VNREZ Recorder"
			else
				[[ "$endnotif" == true ]] && notify-send "Recording(s) Aborted" "The upload has been aborted." -a "VNREZ Recorder"
			fi
			check=true
		fi
	elif [[ -f "$upload_lockfile" ]]; then
		upload_lock_pid=$(cat "$upload_lockfile")
		if kill -0 "$upload_lock_pid" 2>/dev/null; then
			pkill -P "$upload_lock_pid"
			kill "$upload_lock_pid"
			if [[ -f "$upload_lockfile" ]]; then
				rm "$upload_lockfile"
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
	elif [[ "$service" == "emogirls" ]]; then
		upload_image=$(curl -X POST -F "file=@"$temp_file -H "X-API-Key: "$auth -w "%{http_code}" -o $response -s "$url")
	else
		if [[ -f "$CONFIG_DIR/services/${service}" ]]; then
			source "$CONFIG_DIR/services/${service}"
			upload_image=$(curl -X POST -F "${file_form_name}=@"$temp_file -H "${auth_header}: "$auth_token -w "%{http_code}" -o $response -s "$request_url")
		else
			notify-send "Error: Custom service '$service' not found" -a "Flameshot"
			exit 1
		fi
	fi

	http_code="${upload_image: -3}"
	if [[ "$http_code" -ne 200 ]]; then
		if [[ "$http_code" -eq 403 ]]; then
			notify-send "Error: Code: $http_code" "Upload failed. API key may be incorrect." -a "Flameshot"
		else
			notify-send "Error: Code: $http_code" "Upload failed. Please check the service status." -a "Flameshot"
		fi
		
		if [[ "$failsave" == true ]]; then
			mkdir -p "$(eval echo $photodir)/failed" 2>/dev/null
			cp "$temp_file" "$(eval echo $photodir)/failed/screenshot_$(date +%Y%m%d_%H%M%S).png"
		fi
		
		rm $temp_file
		exit 1
	fi

	if [[ "$service" == "e-z" ]]; then
		success=$(cat /tmp/upload.json | jq -r ".success")
		if [[ "$success" != "true" ]] || [[ "$success" == "null" ]]; then
			error=$(cat /tmp/upload.json | jq -r ".error")
			if [[ "$error" == "null" ]]; then
				notify-send "Error occurred while uploading. Try again later." -a "Flameshot"
				
				if [[ "$failsave" == true ]]; then
					mkdir -p "$(eval echo $photodir)/failed" 2>/dev/null
					cp "$temp_file" "$(eval echo $photodir)/failed/screenshot_$(date +%Y%m%d_%H%M%S).png"
				fi
				
				rm $temp_file
				exit 1
			else
				notify-send "Error: $error" -a "Flameshot"
				
				if [[ "$failsave" == true ]]; then
					mkdir -p "$(eval echo $photodir)/failed" 2>/dev/null
					cp "$temp_file" "$(eval echo $photodir)/failed/screenshot_$(date +%Y%m%d_%H%M%S).png"
				fi
				
				rm $temp_file
				exit 1
			fi
		fi
	fi

	if ! jq -e . >/dev/null 2>&1 <$response; then
		notify-send "Error occurred while uploading. Invalid response." -a "Flameshot"
		
		if [[ "$failsave" == true ]]; then
			mkdir -p "$(eval echo $photodir)/failed" 2>/dev/null
			cp "$temp_file" "$(eval echo $photodir)/failed/screenshot_$(date +%Y%m%d_%H%M%S).png"
		fi
		
		rm $temp_file
		exit 1
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
		
		if [[ "$failsave" == true ]]; then
			mkdir -p "$(eval echo $photodir)/failed" 2>/dev/null
			cp "$temp_file" "$(eval echo $photodir)/failed/screenshot_$(date +%Y%m%d_%H%M%S).png"
		fi
		
		rm $temp_file
		exit 1
	fi

	if [[ "$service" == "e-z" ]]; then
		image_url=$(cat $response | jq -r .imageUrl)
	elif [[ "$service" == "nest" ]]; then
		image_url=$(cat $response | jq -r .fileURL)
	elif [[ "$service" == "emogirls" ]]; then
		image_url=$(cat $response | jq -r .url)
	else
		if [[ -f "$CONFIG_DIR/services/${service}" ]]; then
			source "$CONFIG_DIR/services/${service}"
			image_url=$(cat $response | jq -r ".$url_json_path")
		fi
	fi

	if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
		echo $image_url | wl-copy
	else
		echo $image_url | xclip -sel c
	fi
	
	if [[ "$photosave" == true ]]; then
		mkdir -p "$(eval echo $photodir)" 2>/dev/null
		cp "$temp_file" "$(eval echo $photodir)/screenshot_$(date +%Y%m%d_%H%M%S).png"
		notify-send "Screenshot saved" "$(eval echo $photodir)/" -a "Flameshot" -i $temp_file
	fi
	
	notify-send "Image URL copied to clipboard" -a "Flameshot" -i $temp_file
	
	if [[ "$photosave" != true ]]; then
		rm $temp_file
	fi
}

shorten_url() {
    local url=$1
    
    if [ "$service" = "none" ]; then
        notify-send "VNREZ URL Shortener" "No Service selected"
        echo "No Service selected. Set a service in your config file."
        exit 1
    fi
    
    echo -n " "
    spinner_pid=""
    if [[ "$1" != "--daemon" ]]; then
        (
        spinner='-\|/'
        i=0
        while :; do
            i=$(( (i+1) % 4 ))
            printf "\b%s" "${spinner:$i:1}"
            sleep 0.1
        done
        ) &
        sleep 0.25
        spinner_pid=$!
        trap 'kill $spinner_pid 2>/dev/null' EXIT
    fi
    
    case $service in
        "e-z")
            response=$(curl -s -w "%{http_code}" -X POST "$ez_shortener" \
                -H "key: $auth" \
                -H "Content-Type: application/json" \
                -d "{\"url\":\"$url\"}")
            http_code=${response: -3}
            response=${response%???}
            shortened_url=$(echo "$response" | jq -r '.shortendUrl')
            ;;
        "nest")
            response=$(curl -s -w "%{http_code}" -X PUT "$nest_shortener" \
                -H "Authorization: $auth" \
                -H "Content-Type: application/json" \
                -d "{\"url\":\"$url\", \"domain\":\"$domain\", \"subDomain\":\"$subdomain\", \"embedType\":\"Target\", \"urlType\":\"$urltype\", \"length\":$length, \"password\":\"\"}")
            http_code=${response: -3}
            response=${response%???}
            shortened_url=$(echo "$response" | jq -r '.url')
            ;;
        *) echo "Invalid service"; kill $spinner_pid 2>/dev/null; exit 1 ;;
    esac

    kill $spinner_pid 2>/dev/null
    printf "\b \b"
    echo -n -e "\r\033[K"
    
    if [ "$http_code" = "400" ]; then
        notify-send "Rate Limited" "You are being rate limited. Please try again later."
    elif [ -n "$shortened_url" ] && [ "$shortened_url" != "null" ]; then
        if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
            echo "$shortened_url" | wl-copy
        else
            echo "$shortened_url" | xclip -selection clipboard
        fi
        [[ "$shortener_notif" == true ]] && notify-send "URL Shortened" "$shortened_url"
        echo "Successfully shortened URL: $shortened_url"
    else
        notify-send "Failed to shorten URL" "$url"
        printf "\033[1;5;31mERROR:\033[0m Failed to shorten URL: $url\n"
    fi
}

post_process_video() {
	local input_file=$1
	local output_file="${input_file%.mp4}_processed.mp4"
	ffmpeg -i "$input_file" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,format=$pixelformat" -colorspace bt709 -color_primaries bt709 -color_trc bt709 -c:v $encoder -preset $preset -crf $crf -movflags +faststart -c:a copy "$output_file"
	mv "$output_file" "$input_file"
}

