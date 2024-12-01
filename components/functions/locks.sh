acquire_lock() {
	if [[ -f "$lockfile" ]]; then
		other_pid=$(cat "$lockfile")
		if kill -0 "$other_pid" 2>/dev/null; then
			echo "Another instance of slurp or slop is already running."
			exit 1
		else
			echo $$ >"$lockfile"
		fi
	else
		echo $$ >"$lockfile"
	fi
}

release_lock() {
	rm -f "$lockfile"
}