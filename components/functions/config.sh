SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "$SCRIPT_DIR/components/functions/variables.sh"

create_config() {
	local service=$1
	local auth_token=$2
	local fps=$3
	local crf=$4
	local preset=$5
	local pixelformat=$6
	local extpixelformat=$7
	local wlscreenrec=$8
	local codec=${9}
	local directory=${10}
	local failsave=${11}
	local save=${12}
	local encoder=${13}
	local startnotif=${14}
	local endnotif=${15}
	local grimshot=${16}
	local blast=${17}
	local bitrate=${18}
	local shortener_notif=${19}

	mkdir -p "$CONFIG_DIR"

	cat >"$CONFIG_FILE" <<EOL
service="$service"
auth="$auth_token"
fps=$fps
crf=$crf
preset=$preset
pixelformat=$pixelformat
encoder=$encoder
save=$save
failsave=$failsave
colorworkaround=false
startnotif=$startnotif
endnotif=$endnotif

grimshot=$grimshot
blast=$blast

shortener_notif=$shortener_notif

wlscreenrec=$wlscreenrec
codec=$codec
extpixelformat=$extpixelformat
bitrate=$bitrate

directory="$directory"
kooha_dir="~/Videos/Kooha"
EOL

	if [[ "$prompt_service" != true ]]; then
		notify-send "Configuration Created" "VNEZ configuration has been created successfully" -a "VNEZ Recorder"
	fi
}

update_config() {
	local config_path="$(eval echo $CONFIG_FILE)"
	local updated=false
	local new_config_content=""

	local default_config_content=$(
		cat <<EOL
service=
auth=
fps=60
crf=20
preset=fast
pixelformat=yuv420p
encoder=libx264
save=false
failsave=true
colorworkaround=false
startnotif=true
endnotif=true

grimshot=false
blast=false

shortener_notif=false

wlscreenrec=false
codec=auto
extpixelformat=nv12
bitrate="5 MB"

directory="~/Videos"
kooha_dir="~/Videos/Kooha"
EOL
	)

	declare -A existing_config
	while IFS='=' read -r key value; do
		[[ "$key" =~ ^#.*$ || -z "$key" || -z "$value" ]] && continue
		if [[ "$key" == "ez_auth" || "$key" == "nest_auth" ]]; then
			existing_config["auth"]="$value"
		else
			existing_config["$key"]="$value"
		fi
	done < <(grep -v '^#' "$config_path")

	while IFS= read -r line; do
		if [[ "$line" =~ ^#.*$ || -z "$line" ]]; then
			new_config_content+="$line"$'\n'
			continue
		fi
		key=$(echo "$line" | cut -d '=' -f 1)
		if [[ "$key" == "auth" ]]; then
			new_config_content+="$key=${existing_config[$key]}"$'\n'
			unset existing_config["$key"]
		elif [[ -z "${existing_config[$key]}" ]]; then
			new_config_content+="$line"$'\n'
			updated=true
		else
			new_config_content+="$key=${existing_config[$key]}"$'\n'
			unset existing_config["$key"]
		fi
	done <<<"$default_config_content"

	new_config_content=$(echo -n "$new_config_content")
	if [[ "$new_config_content" != "$(cat "$config_path")" ]]; then
		echo "$new_config_content" >"$config_path"
		echo "Configuration updated."
	fi
}
