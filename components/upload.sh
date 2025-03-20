#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/functions/variables.sh"
source "$SCRIPT_DIR/functions/checks.sh"
source "$SCRIPT_DIR/functions/misc.sh"
source "$SCRIPT_DIR/functions/core.sh"

[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

check_dependencies
check_root
check_variables

upload_mode=true

handle_lockfile() {
	if [[ -f "$upload_lockfile" ]]; then
		local other_pid=$(cat "$upload_lockfile")
		if kill -0 "$other_pid" 2>/dev/null; then
			read -p "Another upload running. Terminate? (Y/N): " confirm
			if [[ "$confirm" =~ ^[Yy] ]]; then
				kill "$other_pid"
			else
				echo "Waiting for other process..."
				while [[ -f "$upload_lockfile" ]] && \
				      kill -0 $(cat "$upload_lockfile") 2>/dev/null; do
					sleep 2.5
				done
			fi
		fi
	fi
	echo $$ >"$upload_lockfile"
}

cleanup() {
	rm -f "$upload_lockfile"
	trap - INT TERM EXIT
	exit $1
}

validate_files() {
	if [[ $# -eq 0 ]]; then
		printf "\033[1m(?) \033[0mNo files specified for upload.\n"
		cleanup 1
	fi

	if [[ $# -ge 6 ]]; then
		printf "\033[1;5;31mERROR:\033[0m Too many files specified.  "
		printf "Please upload fewer than 6 files at a time.\n"
		cleanup 1
	fi
}

process_file() {
	local file="$1"
	local filename=$(basename "$file")
	local extension="${filename##*.}"
	local file_key="${file}:${filename}"

	if [[ -d "$file" || "$filename" == "$extension" ]]; then
		printf "\033[1;5;31mERROR:\033[0m \033[1;34m\033[7m$file\033[0m "
		printf "is a Directory or file that doesn't have a extension.\n"
		return
	fi

	if [[ -n "${processed_files[$file_key]}" ]]; then
		printf "\033[1;5;33m(!)\033[0m Skipping Duplicated Video: "
		printf "\033[1;34m\033[7m$filename\033[0m\n"
		return
	fi

	if [[ "$service" == "none" ]]; then
		printf "\033[1m[1/4] \033[0mChecking if\033[1;34m $filename "
		printf "\033[0mexists\n"
		sleep 0.3
		printf "\033[1;5;31mERROR:\033[0m Service is none.\n"
		cleanup 1
	fi

	if [[ ! -f "$file" ]]; then
		printf "\n\033[1m[1/4] \033[0mChecking if\033[1;34m $filename "
		printf "\033[0mexists\n"
		sleep 0.3
		printf "\033[1;5;31mERROR:\033[0m File not found:"
		printf "\033[1;34m $filename\033[0m\n"
		return
	fi
	sleep 0.1
	printf "\n\033[1m[1/4] \033[0mChecking if\033[1;34m $filename "
	printf "\033[0mexists\n"
	sleep 0.2
	printf "\033[1m[2/4]\033[0m\033[1;34m $filename \033[0mfound\n"
	sleep 0.2
	printf "\033[1m[3/4]\033[0m Uploading:\033[1;34m $filename \033[0m"
	upload_video "$file" &
	spinner $!
	wait $!

	handle_upload_response "$file" "$filename" "$file_key"
}

handle_upload_response() {
	local file="$1"
	local filename="$2"
	local file_key="$3"

	if [[ $? -eq 0 && -f $response_video ]]; then
		local upload_url
		if [[ "$service" == "e-z" ]]; then
			upload_url=$(jq -r ".imageUrl" <$response_video)
		elif [[ "$service" == "nest" ]]; then
			upload_url=$(jq -r ".fileURL" <$response_video)
		fi
		if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
			echo "$upload_url" | xclip -selection clipboard
		else
			echo "$upload_url" | wl-copy
		fi
		processed_files["$file_key"]=1
	fi

	if [[ $? -eq 0 && -n "$upload_url" ]]; then
		printf "\n\033[1m[4/4]\033[0m Upload successful: "
		printf "\033[1;32m%s\033[0m$upload_url\n\n"
		[[ -f $response_video ]] && rm $response_video
	else
		printf "\n\033[1;5;31mERROR:\033[0m Failed to upload file: "
		printf "\033[1;34m%s\033[0m$filename\n\n"
	fi
}

handle_lockfile

files=("$@")
validate_files "${files[@]}"

declare -A processed_files
file_count=0

for file in "${files[@]}"; do
	process_file "$file"
	((file_count++))
	if ((file_count % 3 == 0)); then
		sleep 3.8
	fi
done

cleanup 0
