#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/functions/variables.sh"
source "$SCRIPT_DIR/functions/checks.sh"
source "$SCRIPT_DIR/functions/core.sh"

if [ -f "$CONFIG_FILE" ]; then
	source "$CONFIG_FILE"
fi

check_dependencies
check_root

if [[ "$1" != "auto" && -f "$CONFIG_FILE" ]]; then
	check_variables
fi

if [[ "$XDG_CURRENT_DESKTOP" != "Hyprland" ]]; then
		echo "Error: This grimblast variant is intended to be used only on Hyprland."
		exit 1
fi

if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
	service="none"
	endnotif="true"
	shift
fi

CURSOR=
FREEZE=
WAIT=no
SCALE=
HYPRPICKER_PID=-1

while [ $# -gt 0 ]; do
  key="$1"

  case $key in
  -c | --cursor)
    CURSOR=yes
    shift
    ;;
  -f | --freeze)
    FREEZE=yes
    shift
    ;;
  -w | --wait)
    shift
    WAIT=$1
    if [[ ! "$WAIT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      echo "Invalid value for wait '$WAIT'" >&2
      exit 3
    fi
    shift
    ;;
  -s | --scale)
    shift
    if [ $# -gt 0 ]; then
      SCALE="$1"
      shift
    else
      echo "Error: Missing argument for --scale option."
      exit 1
    fi
    ;;
  shot)
    SUBJECT="--area"
    shift
    ;;
  *)
    SUBJECT="$1"
    shift
    ;;
  esac
done

if [ -z "$SUBJECT" ]; then
  SUBJECT="--area"
fi

killHyprpicker() {
  if [ ! $HYPRPICKER_PID -eq -1 ]; then
    kill $HYPRPICKER_PID
  fi
}

die() {
  killHyprpicker
  MSG=${1:-Bye}
  notify-send "Error: $MSG" -a "grimshot"
  exit 2
}


takeScreenshot() {
  GEOM=$1
  OUTPUT=$2
  if [ -n "$OUTPUT" ]; then
    grim ${CURSOR:+-c} ${SCALE:+-s "$SCALE"} -o "$OUTPUT" "$temp_file" || die "Unable to invoke grim"
  elif [ -z "$GEOM" ]; then
    grim ${CURSOR:+-c} ${SCALE:+-s "$SCALE"} "$temp_file" || die "Unable to invoke grim"
  else
    grim ${CURSOR:+-c} ${SCALE:+-s "$SCALE"} -g "$GEOM" "$temp_file" || die "Unable to invoke grim"
  fi

if [[ "$service" == "none" ]]; then
	[[ "$endnotif" == true ]] && notify-send "Image copied to clipboard" -a "grimshot" -i $temp_file
	if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
		cat $temp_file | wl-copy
	else
		cat $temp_file | xclip -sel c
	fi
	rm $temp_file
	exit 0
fi

upload_shot
}

wait() {
  if [ "$WAIT" != "no" ]; then
    sleep "$WAIT"
  fi
}

if [ "$SUBJECT" = "--active" ]; then
  wait
  FOCUSED=$(hyprctl activewindow -j)
  GEOM=$(echo "$FOCUSED" | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
  takeScreenshot "$GEOM" ""
elif [ "$SUBJECT" = "--screen" ]; then
  wait
  takeScreenshot "" ""
elif [ "$SUBJECT" = "--output" ]; then
  wait
  OUTPUT=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true)' | jq -r '.name')
  takeScreenshot "" "$OUTPUT"
elif [ "$SUBJECT" = "--area" ]; then
  if [ "$FREEZE" = "yes" ] && [ "$(command -v "hyprpicker")" ] >/dev/null 2>&1; then
    hyprpicker -r -z &
    sleep 0.2
    HYPRPICKER_PID=$!
  fi

  hyprctl keyword layerrule "noanim,selection" >/dev/null

  FULLSCREEN_WORKSPACES="$(hyprctl workspaces -j | jq -r 'map(select(.hasfullscreen) | .id)')"
  WORKSPACES="$(hyprctl monitors -j | jq -r '[(foreach .[] as $monitor (0; if $monitor.specialWorkspace.name == "" then $monitor.activeWorkspace else $monitor.specialWorkspace end)).id]')"
  WINDOWS="$(hyprctl clients -j | jq -r --argjson workspaces "$WORKSPACES" --argjson fullscreenWorkspaces "$FULLSCREEN_WORKSPACES" 'map((select(([.workspace.id] | inside($workspaces)) and ([.workspace.id] | inside($fullscreenWorkspaces) | not) or .fullscreen > 0)))')"
  GEOM=$(echo "$WINDOWS" | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp $SLURP_ARGS)

  if [ -z "$GEOM" ]; then
    killHyprpicker
    exit 1
  fi
  WHAT="Area"
  wait
  takeScreenshot "$GEOM" ""
else
  if [ "$SUBJECT" = "auto" ]; then
    eval "$3"
  else
    die "Invalid argument: \"$SUBJECT\""
  fi
fi

rm $temp_file
killHyprpicker
