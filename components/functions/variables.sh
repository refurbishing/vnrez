CONFIG_DIR="$HOME/.config/vnrez"
CONFIG_FILE="$CONFIG_DIR/config.conf"

if [ -f "$CONFIG_FILE" ]; then
	source "$CONFIG_FILE"
fi

ez="https://api.e-z.host/files"
nest="https://nest.rip/api/files/upload"

temp_file="/tmp/screenshot.png"
response="/tmp/upload.json"
response_video="/tmp/upload_video.json"
gif_pending_file="/tmp/gif_pending"
kooha_last_time="$CONFIG_DIR/last_time"

valid_extensions=("mp4" "mkv" "webm" "gif")

lockfile="$CONFIG_DIR/.script.lck"
upload_lockfile="$CONFIG_DIR/.upload.lck"

if [ "$service" = "e-z" ]; then
	auth=$ez_auth
elif [ "$service" = "nest" ]; then
	auth=$nest_auth
fi

if [ "$service" = "e-z" ]; then
	url=$ez
elif [ "$service" = "nest" ]; then
	url=$nest
fi
