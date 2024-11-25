SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/functions/variables.sh"
source "$SCRIPT_DIR/functions/checks.sh"
source "$SCRIPT_DIR/functions/misc.sh"
source "$SCRIPT_DIR/functions/core.sh"

check_dependencies
check_root
check_variables

upload_mode=true
if [[ -f "$upload_lockfile" ]]; then
	other_pid=$(cat "$upload_lockfile")
	if kill -0 "$other_pid" 2>/dev/null; then
		echo "Another upload process is already running."
		read -p "Do you want to terminate the other upload process? (Y/N): " confirm
		if [[ "$confirm" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
			kill "$other_pid"
		else
			echo "Waiting for the other upload process to finish..."
			while [[ -f "$upload_lockfile" ]] && kill -0 $(cat "$upload_lockfile") 2>/dev/null; do
				sleep 2.5
			done
		fi
	fi
fi
echo $$ >"$upload_lockfile"
trap 'rm -f "$upload_lockfile"; exit' INT TERM EXIT

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
	printf "\033[1m(?) \033[0mNo files specified for upload.\n"
	exit 1
fi

if [[ ${#files[@]} -ge 6 ]]; then
	printf "\033[1;5;31mERROR:\033[0m Too many files specified for upload. Please upload fewer than 6 files at a time.\n"
	rm -f "$upload_lockfile"
	exit 1
fi

declare -A processed_files
file_count=0

for file in "${files[@]}"; do
	filename=$(basename "$file")
	extension="${filename##*.}"
	file_key="${file}:${filename}"

	if [[ -d "$file" || "$filename" == "$extension" ]]; then
		printf "\033[1;5;31mERROR:\033[0m \033[1;34m\033[7m$file\033[0m is a Directory or file that doesn't have a extension.\n"
		continue
	elif [[ ! " ${valid_extensions[@]} " =~ " ${extension} " ]]; then
		printf "\033[1;5;31mERROR:\033[0m Unsupported file type: \033[1;34m${filename%.*}\033[4m.${extension}\033[0m\n"
		continue
	fi

	if [[ -n "${processed_files[$file_key]}" ]]; then
		printf "\033[1;5;33m(!)\033[0m Skipping Duplicated Video: \033[1;34m\033[7m$filename\033[0m\n"
		continue
	fi

	if [[ "$service" == "none" ]]; then
		printf "\033[1m[1/4] \033[0mChecking if\033[1;34m $filename \033[0mexists\n"
		sleep 0.3
		printf "\033[1;5;31mERROR:\033[0m Service is none.\n"
		exit 1
	fi

	if [[ ! -f "$file" ]]; then
		printf "\n\033[1m[1/4] \033[0mChecking if\033[1;34m $filename \033[0mexists\n"
		sleep 0.3
		printf "\033[1;5;31mERROR:\033[0m File not found:\033[1;34m $filename\033[0m\n"
		continue
	fi
	sleep 0.1
	printf "\n\033[1m[1/4] \033[0mChecking if\033[1;34m $filename \033[0mexists\n"
	sleep 0.2
	printf "\033[1m[2/4]\033[0m\033[1;34m $filename \033[0mfound\n"
	sleep 0.2
	printf "\033[1m[3/4]\033[0m Uploading:\033[1;34m $filename \033[0m"
	((file_count++))
	upload_video "$file" &
	spinner $!

	if [[ $? -eq 0 && -f $response_video ]]; then
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
		printf "\n\033[1m[4/4]\033[0m Upload successful: \033[1;32m%s\033[0m$upload_url\n\n"
		[[ -f $response_video ]] && rm $response_video
	else
		printf "\n\033[1;5;31mERROR:\033[0m Failed to upload file: \033[1;34m%s\033[0m$filename\n\n"
	fi
	if ((file_count % 3 == 0)); then
		sleep 3.8
	fi
done

rm -f "$upload_lockfile"
trap - INT TERM EXIT
exit 0
