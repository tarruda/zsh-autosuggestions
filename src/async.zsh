
#--------------------------------------------------------------------#
# Async                                                              #
#--------------------------------------------------------------------#

zmodload zsh/system

_zsh_autosuggest_async_request() {
	typeset -g _ZSH_AUTOSUGGEST_ASYNC_FD _ZSH_AUTOSUGGEST_CHILD_PID

	# If we've got a pending request, cancel it
	if [[ -n "$_ZSH_AUTOSUGGEST_ASYNC_FD" ]] && { true <&$_ZSH_AUTOSUGGEST_ASYNC_FD } 2>/dev/null; then
		# Close the file descriptor
		exec {_ZSH_AUTOSUGGEST_ASYNC_FD}<&-

		# Assume the child process created a new process group and send
		# TERM to the group to attempt to kill all descendent processes
		kill -TERM -$_ZSH_AUTOSUGGEST_CHILD_PID 2>/dev/null
	fi

	# Fork a process to fetch a suggestion and open a pipe to read from it
	exec {_ZSH_AUTOSUGGEST_ASYNC_FD}< <(
		# Tell parent process our pid
		echo $sysparams[pid]

		# Fetch and print the suggestion
		local suggestion
		_zsh_autosuggest_fetch_suggestion "$1"
		echo -nE "$suggestion"
	)

	# Read the pid from the child process
	read _ZSH_AUTOSUGGEST_CHILD_PID <&$_ZSH_AUTOSUGGEST_ASYNC_FD

	# When the fd is readable, call the response handler
	zle -F "$_ZSH_AUTOSUGGEST_ASYNC_FD" _zsh_autosuggest_async_response
}

# Called when new data is ready to be read from the pipe
# First arg will be fd ready for reading
# Second arg will be passed in case of error
_zsh_autosuggest_async_response() {
	# Read everything from the fd and give it as a suggestion
	zle autosuggest-suggest -- "$(cat <&$1)"

	# Remove the handler and close the fd
	zle -F "$1"
	exec {1}<&-
}
