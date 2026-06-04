set betterShotBundleID to "com.kartiklabhshetwar.bettershot"
set settingsPath to (POSIX path of (path to home folder)) & "Library/Application Support/com.kartiklabhshetwar.bettershot/settings.json"
set saveDir to POSIX path of (path to desktop folder)

try
    set saveDir to do shell script "/usr/bin/plutil -extract saveDir raw -o - " & quoted form of settingsPath
end try

do shell script "/bin/mkdir -p " & quoted form of saveDir

set timestamp to do shell script "/bin/date +%Y-%m-%d-%H%M%S"
set screenshotPath to saveDir & "/BetterShot-" & timestamp & ".png"

tell application "System Events"
    set isBetterShotRunning to exists application process "bettershot"
end tell

if isBetterShotRunning is false then
    tell application id betterShotBundleID to launch
    delay 0.4
end if

try
    -- Start the real drag-to-select screenshot UI. Press Escape to cancel.
    do shell script "/usr/sbin/screencapture -i -s -x " & quoted form of screenshotPath
on error
    return
end try

set screenshotExists to do shell script "/bin/test -s " & quoted form of screenshotPath & " && echo yes || echo no"

if screenshotExists is "yes" then
    do shell script "/usr/bin/open -b " & quoted form of betterShotBundleID & " " & quoted form of screenshotPath
end if
