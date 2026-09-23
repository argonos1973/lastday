-- LastDayServer launcher applet.
-- Wraps the headless dedicated-server binary so macOS quit events (Dock >
-- Salir, Cmd+Q, "tell application ... to quit") reach us: the exported
-- dedicated_server build is headless, so Godot's applicationShouldTerminate
-- never forwards NOTIFICATION_WM_CLOSE_REQUEST to scripts. This applet takes
-- the stop-flag path instead: on quit it touches user://stop_server.flag and
-- the server saves the world and exits by itself.

global serverPID
global flagPath

on run
	set coreApp to (POSIX path of (path to me)) & "Contents/Resources/LastDayServerCore.app/"
	set coreBin to coreApp & "Contents/MacOS/Un dia mas"
	set supportDir to (POSIX path of (path to application support from user domain)) & "Godot/app_userdata/Un dia mas"
	set flagPath to supportDir & "/stop_server.flag"
	set logPath to supportDir & "/server_stdout.log"
	set serverPID to 0
	-- Adopt a server that is already running (e.g. launcher was reopened).
	try
		set serverPID to (do shell script "pgrep -f " & quoted form of (coreApp & "Contents/MacOS")) as integer
	end try
	if serverPID is 0 then
		do shell script "mkdir -p " & quoted form of supportDir
		set serverPID to (do shell script quoted form of coreBin & " >> " & quoted form of logPath & " 2>&1 & echo $!") as integer
	end if
end run

on idle
	if serverPID > 0 then
		try
			do shell script "kill -0 " & serverPID
		on error
			quit -- server ended on its own; close the launcher too
		end try
	end if
	return 2
end idle

on quit
	if serverPID > 0 then
		try
			do shell script "touch " & quoted form of flagPath
		end try
		-- The server polls the flag every 2 s and saves before exiting.
		repeat 40 times
			try
				do shell script "kill -0 " & serverPID
				delay 1
			on error
				exit repeat
			end try
		end repeat
		try
			do shell script "kill -0 " & serverPID
			do shell script "kill -TERM " & serverPID
		end try
	end if
	continue quit
end quit
