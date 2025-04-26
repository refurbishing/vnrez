SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/components/functions/variables.sh"

handle_cases() {
if [[ -n "$handle_auto" && ! " ${valid_cases[@]} " =~ " $handle_auto " ]]; then
	notify-send "Invalid Case: $handle_auto" -a "VNREZ Recorder"
	echo "Case: \"$handle_auto\" is not valid or recognized."
	echo "Use --help or -h to see the list of valid cases."
	exit 1
fi
}

handle_args() {
    if [[ ("$1" == "auto" && -n "$3") && "$2" != "upload" && "$2" != "-u" ]]; then
        if [[ "$2" == "shot" && "$3" != "--host" && ! " ${shot_args[@]} " =~ " $3 " ]]; then
            notify-send "Invalid argument: $3" -a "VNREZ Recorder"
            echo "Argument: \"$3\" is not a valid shot argument."
            echo "Use --help or -h to see the list of valid arguments."
            exit 1
        elif [[ "$2" == "record" && "$3" != "--host" && ! " ${record_args[@]} " =~ " $3 " ]]; then
            notify-send "Invalid argument: $3" -a "VNREZ Recorder"
            echo "Argument: \"$3\" is not a valid record argument."
            echo "Use --help or -h to see the list of valid arguments."
            exit 1
        fi
    elif [[ -n "$2" && "$1" != "-u" && "$1" != "upload" ]]; then
        if [[ "$1" == "shot" && "$2" != "--host" && ! " ${shot_args[@]} " =~ " $2 " ]]; then
            notify-send "Invalid argument: $2" -a "VNREZ Recorder"
            echo "Argument: \"$2\" is not a valid shot argument."
            echo "Use --help or -h to see the list of valid arguments."
            exit 1
        elif [[ "$1" == "record" && "$2" != "--host" && ! " ${record_args[@]} " =~ " $2 " ]]; then
            notify-send "Invalid argument: $2" -a "VNREZ Recorder"
            echo "Argument: \"$2\" is not a valid record argument."
            echo "Use --help or -h to see the list of valid arguments."
            exit 1
        fi
    fi
}