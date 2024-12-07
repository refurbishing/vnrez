#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/components/functions/variables.sh"
source "$SCRIPT_DIR/components/functions/config.sh"
source "$SCRIPT_DIR/components/functions/checks.sh"
source "$SCRIPT_DIR/components/functions/misc.sh"
source "$SCRIPT_DIR/components/functions/locks.sh"

if [ -f "$CONFIG_FILE" ]; then
	source "$CONFIG_FILE"
fi


if [[ -n "$1" && ! " ${valid_args[@]} " =~ " $1 " ]]; then
	notify-send "Invalid argument: $1" -a "VNREZ Recorder"
	echo "Argument: \"$1\" is not valid."
	echo "Use '--help' or '-h' to see the list of valid arguments."
	exit 1
fi

if [[ "$1" == "--help" || "$1" == "-h" || "$2" == "--help" || "$2" == "-h" ]]; then
	help
fi

check_root
check_dependencies

initial_setup() {
	echo -e "Initializing.."
	services=("e-z" "nest" "none")
	selected=0

	find "$SCRIPT_DIR/components" -type f -exec chmod +x {} \;

	tput clear

	prev_rows=$(tput lines)
	prev_cols=$(tput cols)

	while true; do
		rows=$(tput lines)
		cols=$(tput cols)

		if [[ $rows -ne $prev_rows || $cols -ne $prev_cols ]]; then
			tput clear
			prev_rows=$rows
			prev_cols=$cols
		fi

		tput civis
		tput cup 0 0

		rows=$(tput lines)
		cols=$(tput cols)
		vpad=$(((rows - 20) / 2))
		hpad=$(((cols - 40) / 2))

		for ((i = 0; i < vpad; i++)); do echo; done

		printf "%${hpad}s" ""
		logo_setup | while IFS= read -r line; do
			printf "%${hpad}s%s\n" "" "$line"
		done
		printf "%${hpad}s" ""
		printf "       \e[36mWelcome to VNREZ Configuration\e[0m\n"
		printf "%${hpad}s" ""
		printf "Select your preferred host using arrow keys:\n"

		for i in "${!services[@]}"; do
			printf "%${hpad}s" ""
			if [[ "${services[$i]}" == "none" ]]; then
				if [[ $i -eq $selected ]]; then
					echo -e "\e[32m◆ ${services[$i]}\e[0m"
				else
					echo "◇ ${services[$i]}"
				fi
			else
				if [[ $i -eq $selected ]]; then
					echo -e "\e[32m• ${services[$i]}\e[0m"
				else
					echo "◦ ${services[$i]}"
				fi
			fi
		done

		read -rsn1 input
		case $input in
		$'\x1b')
			read -rsn2 -t 0.1 input
			if [[ $input == "[D" ]]; then
				((selected--))
				if [[ $selected -lt 0 ]]; then
					selected=$((${#services[@]} - 1))
				fi
			elif [[ $input == "[C" ]]; then
				((selected++))
				if [[ $selected -ge ${#services[@]} ]]; then
					selected=0
				fi
			fi
			;;
		"W" | "w" | "A" | "a")
			((selected--))
			if [[ $selected -lt 0 ]]; then
				selected=$((${#services[@]} - 1))
			fi
			;;
		"S" | "s" | "D" | "d")
			((selected++))
			if [[ $selected -ge ${#services[@]} ]]; then
				selected=0
			fi
			;;
		"")
			service=${services[$selected]}
			break
			;;
		esac
	done

	tput cnorm

	if [[ "$service" != "none" ]]; then
		echo -e "\e[33mEnter your API Key for $service:\e[0m"
		echo -n "✦ ) "
		auth_token=""
		while [[ -z "$auth_token" || ${#auth_token} -lt 30 ]]; do
			while IFS= read -r -s -n1 char; do
				if [[ $char == "" ]]; then
					echo
					break
				fi
				if [[ $char == $'\x7f' ]]; then
					if [[ -n $auth_token ]]; then
						auth_token=${auth_token%?}
						echo -ne "\b \b"
					fi
				else
					auth_token+="$char"
					echo -n "*"
				fi
			done

			if [[ -z "$auth_token" ]]; then
				echo -e "\e[31mAPI Key cannot be empty!\e[0m"
			elif [[ ${#auth_token} -lt 30 ]]; then
				echo -e "\e[31mAPI Key isn't valid!\e[0m"
			fi

			if [[ -z "$auth_token" || ${#auth_token} -lt 30 ]]; then
				sleep 1
				tput cuu1
				tput el
				tput cuu1
				tput el
				tput cuu1
				tput el
				printf "\e[33mEnter your API Key for $service:\e[0m\n✦ ) "
			fi
		done
	fi

	if [[ "$prompt_service" == true ]]; then
		create_default_config "$service" "$auth_token"
		return
	fi

	if [[ ! ("$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC")) && "$XDG_SESSION_TYPE" != "x11" ]]; then
		screen_recorders=("wf-recorder" "wl-screenrec")
		selected=0

		tput sc

		while true; do
		trap handle_resize SIGWINCH
			tput rc
			tput civis
			tput el
			echo -e "\e[33mChoose your screen recorder:\e[0m"
			for i in "${!screen_recorders[@]}"; do
				if [[ $i -eq $selected ]]; then
					echo -e "\e[32m• ${screen_recorders[$i]}\e[0m"
				else
					echo "◦ ${screen_recorders[$i]}"
				fi
			done

			read -rsn1 input
			case $input in
			$'\x1b')
				read -rsn2 -t 0.1 input
				if [[ $input == "[A" ]]; then
					((selected--))
					if [[ $selected -lt 0 ]]; then
						selected=$((${#screen_recorders[@]} - 1))
					fi
				elif [[ $input == "[B" ]]; then
					((selected++))
					if [[ $selected -ge ${#screen_recorders[@]} ]]; then
						selected=0
					fi
				fi
				;;
			"")
				screen_recorder=${screen_recorders[$selected]}
				break
				;;
			esac
		done

		if [[ "$screen_recorder" == "wl-screenrec" ]]; then
			wlscreenrec=true
		else
			wlscreenrec=false
		fi
	fi
	tput cnorm
	if [[ ! ("$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC")) ]]; then
		echo -e "\e[33mEnter the desired FPS (default is 60):\e[0m"
		echo -n "✦ ) "
		read -r fps
		fps=${fps:-60}
		while ! [[ "$fps" =~ ^[0-9]+$ ]] || [[ $fps -gt 244 ]]; do
			echo -e "\e[31mFPS must be a number and cannot exceed 244. Please enter a valid FPS:\e[0m"
			echo -n "✦ ) "
			read -r fps
			sleep 0.2
		done
	fi

	if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC") ]]; then
		echo -e "\e[33mDo you want to save recordings? (Y/N):\e[0m"
		echo -n "✦ ) "
		read -r save_recordings
		if [[ "$save_recordings" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
			save=true
			echo -e "\e[33mEnter the directory to save files (You need to set it on Kooha too) (default is ~/Videos/Kooha) :\e[0m"
			echo -n "✦ ) "
			read -r kooha_dir
			kooha_dir=${kooha_dir:-"$HOME/Videos/Kooha"}
			while [[ ! -d "$kooha_dir" || "$kooha_dir" == "/" || "$kooha_dir" != "$HOME"* ]]; do
				echo -e "\e[31mInvalid directory! Please enter a valid directory path:\e[0m"
				echo -n "✦ ) "
				read -r kooha_dir
				if [[ "$kooha_dir" == "~"* ]]; then
					kooha_dir="$HOME${kooha_dir:1}"
				fi
				sleep 0.2
			done
		fi
	fi

	if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC") ]]; then
		if [[ "$service" != "none" ]]; then
			echo -e "\e[33mDo you want to enable failsave? (Y/N):\e[0m"
			echo -n "✦ ) "
			read -r failsave_option
			if [[ "$failsave_option" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
				failsave=true
			else
				failsave=false
			fi
		fi
	fi

	if [[ "$wlscreenrec" == false || "$XDG_SESSION_TYPE" == "x11" ]]; then
		echo -e "\e[33mEnter the desired CRF (default is 20):\e[0m"
		echo -n "✦ ) "
		read -r crf
		crf=${crf:-20}
		while ! [[ "$crf" =~ ^[0-9]+$ ]] || [[ $crf -gt 100 ]]; do
			echo -e "\e[31mCRF must be a number and cannot exceed 100. Please enter a valid CRF:\e[0m"
			echo -n "✦ ) "
			read -r crf
			sleep 0.2
		done
	fi
	if [[ "$wlscreenrec" == false || "$XDG_SESSION_TYPE" == "x11" ]]; then
		echo -e "\e[33mEnter the desired preset (default is fast):\e[0m"
		echo -n "✦ ) "
		read -r preset
		sleep 0.2
		preset=${preset:-fast}
	fi

	if [[ "$wlscreenrec" == false || "$XDG_SESSION_TYPE" == "x11" ]]; then
		echo -e "\e[33mEnter the desired pixel format (default is yuv420p):\e[0m"
		echo -n "✦ ) "
		read -r pixelformat
		sleep 0.2
		pixelformat=${pixelformat:-yuv420p}
	fi

	if [[ "$wlscreenrec" == true ]]; then
		echo -e "\e[33mEnter the desired pixel format (default is nv12):\e[0m"
		echo -n "✦ ) "
		read -r extpixelformat
		sleep 0.2
		extpixelformat=${extpixelformat:-nv12}
	fi

	if [[ "$wlscreenrec" == false || "$XDG_SESSION_TYPE" == "x11" ]]; then
		echo -e "\e[33mEnter the desired encoder (default is libx264):\e[0m"
		echo -n "✦ ) "
		read -r encoder
		sleep 0.2
		encoder=${encoder:-libx264}
	fi

	if [[ "$wlscreenrec" == true ]]; then
		echo -e "\e[33mEnter the desired codec (default is auto):\e[0m"
		echo -n "✦ ) "
		read -r codec
		sleep 0.2
		codec=${codec:-auto}
	fi

	if [[ ! ("$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC")) ]]; then
		echo -e "\e[33mDo you want to save recordings? (Y/N):\e[0m"
		echo -n "✦ ) "
		read -r save_recordings
		if [[ "$save_recordings" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
			save=true
			echo -e "\e[33mEnter the directory to save files (default is ~/Videos):\e[0m"
			echo -n "✦ ) "
			read -r directory
			directory=${directory:-"$HOME/Videos"}
			while [[ ! -d "$directory" || "$directory" == "/" || "$directory" != "$HOME"* ]]; do
				echo -e "\e[31mInvalid directory! Please enter a valid directory path:\e[0m"
				echo -n "✦ ) "
				read -r directory
				if [[ "$directory" == "~"* ]]; then
					directory="$HOME${directory:1}"
				fi
				sleep 0.2
			done
		fi

		if [[ "$service" != "none" ]]; then
			echo -e "\e[33mDo you want to enable failsave? (Y/N):\e[0m"
			echo -n "✦ ) "
			read -r failsave_option
			if [[ "$failsave_option" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
				failsave=true
			else
				failsave=false
			fi
		fi
	fi

	if [[ "$XDG_SESSION_TYPE" == "wayland" || "$XDG_SESSION_TYPE" == "x11" ]]; then
		echo -e "\e[33mDo you want to start notifications? (Y/N):\e[0m"
		echo -n "✦ ) "
		read -r startnotif
		if [[ -z "$startnotif" || "$startnotif" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
			startnotif=true
		else
			startnotif=false
		fi
	fi

	if [[ "$XDG_SESSION_TYPE" == "wayland" || "$XDG_SESSION_TYPE" == "x11" ]]; then
		echo -e "\e[33mDo you want to end notifications? (Y/N):\e[0m"
		echo -n "✦ ) "
		read -r endnotif
		if [[ -z "$endnotif" || "$endnotif" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
			endnotif=true
		else
			endnotif=false
		fi
	fi

	create_default_config "$service" "$auth_token" "$fps" "$crf" "$preset" "$pixelformat" "$extpixelformat" "$wlscreenrec" "$codec" "$directory" "$failsave" "$save" "$encoder" "$startnotif" "$endnotif"
}

check_dependencies

if [[ "$1" == "config" ]]; then
	if [[ ! -f "$CONFIG_FILE" ]]; then
		initial_setup
	fi

	if command -v xdg-open >/dev/null; then
		xdg-open "$(eval echo $CONFIG_FILE)"
	elif command -v open >/dev/null; then
		open "$(eval echo $CONFIG_FILE)"
	elif command -v nvim >/dev/null; then
		nvim "$(eval echo $CONFIG_FILE)"
	elif command -v nano >/dev/null; then
		nano "$(eval echo $CONFIG_FILE)"
	else
		echo "No suitable text editor found. Please open $(eval echo $CONFIG_FILE) manually."
	fi
	exit 0
fi

if [[ "$1" == "reinstall" ]]; then
	read -p "Do you want to reinstall the config file with default settings? (Y/N): " confirm
	if [[ "$confirm" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
		initial_setup
	else
		echo "Reinstallation canceled."
	fi
	exit 0
fi

if [[ ! -f "$CONFIG_FILE" && ! ("$1" == "auto" && ("$2" == "record" || "$2" == "shot")) ]]; then
	initial_setup
fi

if [[ -f "$CONFIG_FILE" ]]; then
	source "$CONFIG_FILE"
	update_config
fi

if [[ -z "$1" || ( "$1" == "auto" && -z "$2" ) ]]; then
	options=("record" "shot" "upload" "ǀ" "⨯")
	selected=0
	tput clear

	while true; do
		tput civis
		tput cup 0 0

		rows=$(tput lines)
		cols=$(tput cols)
		vpad=$(((rows - 20) / 2))
		hpad=$(((cols - ${#options[@]} * 15) / 2))
		for ((i = 0; i < vpad; i++)); do echo; done

		logo | while IFS= read -r line; do
			hpad=$(((cols - ${#line}) / 2))
			printf "%${hpad}s%s\n" "" "$line"
		done

		text="Select an option using arrow keys and press Enter:"
		hpad=$(((cols - ${#text}) / 2))
		printf "%${hpad}s" ""
		echo -e "\e[36m$text\e[0m"
		printf "%${hpad}s" ""
		line=""
		for i in "${!options[@]}"; do
			if [[ "${options[$i]}" == "⨯" ]]; then
				if [[ $i -eq $selected ]]; then
					line+="\e[32m⨯\e[0m  "
				else
					line+="⨯  "
				fi
			elif [[ "${options[$i]}" == "ǀ" ]]; then
				line+="ǀ  "
			elif [[ $i -eq $selected ]]; then
				line+="\e[32m• ${options[$i]}\e[0m  "
			else
				line+="◦ ${options[$i]}  "
			fi
		done
		echo -e "$line"

		read -rsn1 input
		case $input in
		$'\x1b')
			read -rsn2 -t 0.1 input
			if [[ $input == "[D" ]]; then
				((selected--))
				while [[ "${options[$selected]}" == "ǀ" ]]; do
					((selected--))
				done
				if [[ $selected -lt 0 ]]; then
					selected=$((${#options[@]} - 1))
				fi
			elif [[ $input == "[C" ]]; then
				((selected++))
				while [[ "${options[$selected]}" == "ǀ" ]]; do
					((selected++))
				done
				if [[ $selected -ge ${#options[@]} ]]; then
					selected=0
				fi
			fi
			;;
		"")
			choice=${options[$selected]}
			if [[ "$choice" == "⨯" ]]; then
				tput cnorm
				exit 0
			fi
			if [[ "$choice" == "upload" ]]; then
				if [[ "$service" == "none" ]]; then
					cols=$(tput cols)
					error_message="ERROR: Service is none."
					hpad=$(((cols - ${#error_message}) / 2))
					printf "%${hpad}s\033[1;5;31mERROR:\033[0m Service is none.\n"
					hpad=$(((cols - ${#text}) / 2))
					printf "%${hpad}s%s" "" "Would you like to add a service? (Y/N): "
					read -r add_service
					if [[ "$add_service" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
						prompt_service=true
						initial_setup
						exec "$0" "$@"
					fi
			else
				tput cnorm
					if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC") ]]; then
						default_save_dir="$(eval echo $kooha_dir)"
					else
						default_save_dir="$(eval echo $directory)"
					fi

					printf "\nEnter the file paths to upload, separated by spaces (limit is 6):\n"
					echo -n "✦ ) "
					file_paths=""
					while IFS= read -r -s -n1 char; do
						if [[ $char == "" ]]; then
							echo
							break
						fi
						if [[ $char == $'\x7f' ]]; then
							if [[ -n $file_paths ]]; then
								file_paths=${file_paths%?}
								echo -ne "\b \b"
							fi
						else
							file_paths+="$char"
							echo -ne "\033[4m$char\033[0m"
						fi
					done
					IFS=' ' read -r -a paths_array <<<"$file_paths"

					for i in "${!paths_array[@]}"; do
						if [[ ! -f "${paths_array[$i]}" && "$save" == true ]]; then
							if [[ -f "$default_save_dir/${paths_array[$i]}" ]]; then
								paths_array[$i]="$default_save_dir/${paths_array[$i]}"
							fi
						fi
					done

					file_paths="${paths_array[*]}"

					"$SCRIPT_DIR/components/upload.sh" $file_paths
					sleep 2.5
					exec "$0" "$@"
					tput civis
				fi
			fi
			if [[ "$choice" == "↩" ]]; then
				exec "$0" "$@"
			fi
			break
			;;
		esac
	done

	tput cnorm
	if [[ "$choice" == "record" ]]; then
		if [[ "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC") ]]; then
			sub_options=("none" "gif" "abort" "ǀ" "↩" "⨯")
		else
			sub_options=("sound" "fullscreen-sound" "fullscreen" "no-sound" "gif" "abort" "ǀ" "↩" "⨯")
		fi
	elif [[ "$choice" == "shot" ]]; then
		sub_options=("gui" "full" "ǀ" "↩" "⨯")
	fi

	selected=0
	tput clear
	while true; do
		tput civis
		tput cup 0 0

		cols=$(tput cols)
		lines=$(tput lines)
		vpad=$(((lines - 8) / 4))
		for ((i = 0; i < vpad; i++)); do
			echo ""
		done

		logo | while IFS= read -r line; do
			hpad=$(((cols - ${#line}) / 2))
			printf "%${hpad}s%s\n" "" "$line"
		done

		text="Select a sub-option for $choice using arrow keys and press Enter:"
		hpad=$(((cols - ${#text}) / 2))
		hpad_small=$(((cols - ${#text}) / 3 + 5))
		printf "%${hpad}s" ""
		echo -e "\e[36m$text\e[0m"
		if [[ "$choice" == "record" && ! ("$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC")) ]]; then
			printf "%${hpad_small}s" ""
		else
			printf "%${hpad}s"""
		fi
		line=""
		for i in "${!sub_options[@]}"; do
			if [[ "${sub_options[$i]}" == "↩" ]]; then
				if [[ $i -eq $selected ]]; then
					line+="\e[32m↩\e[0m  "
				else
					line+="↩  "
				fi
			elif [[ "${sub_options[$i]}" == "⨯" ]]; then
				if [[ $i -eq $selected ]]; then
					line+="\e[32m⨯\e[0m  "
				else
					line+="⨯  "
				fi
			elif [[ "${sub_options[$i]}" == "ǀ" ]]; then
				line+="ǀ  "
			elif [[ $i -eq $selected ]]; then
				line+="\e[32m• ${sub_options[$i]}\e[0m  "
			else
				line+="◦ ${sub_options[$i]}  "
			fi
		done
		echo -e "$line"

		read -rsn1 input
		case $input in
		$'\x1b')
			read -rsn2 -t 0.1 input
			if [[ $input == "[D" ]]; then
				((selected--))
				while [[ "${sub_options[$selected]}" == "ǀ" ]]; do
					((selected--))
				done
				if [[ $selected -lt 0 ]]; then
					selected=$((${#sub_options[@]} - 1))
				fi
			elif [[ $input == "[C" ]]; then
				((selected++))
				while [[ "${sub_options[$selected]}" == "ǀ" ]]; do
					((selected++))
				done
				if [[ $selected -ge ${#sub_options[@]} ]]; then
					selected=0
				fi
			fi
			;;
		"")
			sub_choice=${sub_options[$selected]}
			if [[ "$sub_choice" == "" ]]; then
				tput cnorm
				exit 0
			fi
			if [[ "$sub_choice" == "↩" ]]; then
				exec "$0" "$@"
			fi
			break
			;;
		esac
	done

	tput cnorm
	if [[ "$choice" == "record" ]]; then
		if [[ "$sub_choice" == "none" && "$XDG_SESSION_TYPE" == "wayland" && ("$XDG_CURRENT_DESKTOP" == "GNOME" || "$XDG_CURRENT_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "COSMIC") ]]; then
			sleep 0.5
			"$SCRIPT_DIR/components/record.sh" &>/dev/null
		else
			sleep 0.5
			"$SCRIPT_DIR/components/record.sh" "--$sub_choice" &>/dev/null
		fi
	elif [[ "$choice" == "shot" ]]; then
		sleep 0.5
		"$SCRIPT_DIR/components/shot.sh" "--$sub_choice" &>/dev/null
	fi
	sleep 0.2
	exec "$0" "$@"
fi

if [[ "$1" == "upload" || "$1" == "-u" ]]; then
	"$SCRIPT_DIR/components/upload.sh" "${@:2}"
	exit 0
fi

if [[ "$1" == "shot" || "$2" == "shot" ]]; then
	if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" ]]; then
		"$SCRIPT_DIR/components/shot.sh" auto "${@:2}"
	else
		"$SCRIPT_DIR/components/shot.sh" "${@:2}"
	fi
	exit 0
fi

if [[ "$1" == "record" || "$2" == "record" ]]; then
	if [[ "$2" == "--abort" ]]; then
		"$SCRIPT_DIR/components/record.sh" "${@:2}"
	elif [[ "$1" == "auto" || "$2" == "record" && ! -f "$CONFIG_FILE" ]]; then
		if pgrep -x ffmpeg >/dev/null || pgrep -x wf-recorder >/dev/null || pgrep -x wl-screenrec >/dev/null || pgrep -x kooha >/dev/null; then
			"$SCRIPT_DIR/components/record.sh" auto
			exit 0
		else
			if pgrep -x ffmpeg >/dev/null || pgrep -x wf-recorder >/dev/null || pgrep -x wl-screenrec >/dev/null || pgrep -x kooha >/dev/null; then
				"$SCRIPT_DIR/components/record.sh"
				exit 0
			fi
		fi
		if [[ "$1" == "auto" && ! -f "$CONFIG_FILE" || "$2" == "record" ]]; then
			acquire_lock
			trap release_lock EXIT
			"$SCRIPT_DIR/components/record.sh" auto "${@:3}"
		fi
	else
		acquire_lock
		trap release_lock EXIT
		"$SCRIPT_DIR/components/record.sh" "${@:2}"
	fi
	release_lock
fi

exit 0
