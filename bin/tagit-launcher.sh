#!/usr/bin/env sh

launcherVersion="1.0.1"
launcherName=$(basename "$0")

# Check system requirements
kernel=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
test "$kernel" = "linux" && test "$arch" = "x86_64" || {
    echo "This program requires Linux x86_64"
    read -r _
    exit 1
}

localVersion=$(cat version 2>/dev/null || echo "0.0.0")

# Get latest release info
echo "Checking for updates..."
echo ""

getUpdateType() {
    major1=$(echo "$1" | cut -d '.' -f1)
    minor1=$(echo "$1" | cut -d '.' -f2)
    patch1=$(echo "$1" | cut -d '.' -f3)
    major2=$(echo "$2" | cut -d '.' -f1)
    minor2=$(echo "$2" | cut -d '.' -f2)
    patch2=$(echo "$2" | cut -d '.' -f3)

    if [ "$major1" != "$major2" ]; then
        test "$major1" -gt "$major2" && echo "major" || echo "none"
        return
    fi

    if [ "$minor1" != "$minor2" ]; then
        test "$minor1" -gt "$minor2" && echo "minor" || echo "none"
        return
    fi

    if [ "$patch1" != "$patch2" ]; then
        test "$patch1" -gt "$patch2" && echo "patch" || echo "none"
        return
    fi

    echo "none"
}
launcherReleaseData=$(curl -s "https://api.github.com/repos/ketei/tagit-v3/releases/latest")
launcherReleaseVersion=$(echo "$launcherReleaseData" | grep -o '"tag_name": ".*"' | cut -d '"' -f 4 | tr -cd '[:digit:].')
launcherUpdateType=$(getUpdateType "$launcherReleaseVersion" "$launcherVersion")

test "$launcherUpdateType" != "none" && {
    launcherUpdateArg="--update-launcher=$launcherName"
    echo "Launcher will be updated from $launcherVersion to $launcherReleaseVersion on next run"
    echo ""
}

# Check if updates are disabled
echo "$localVersion" | grep -q "x" && {
    exec ./tagit -- --no-update "$launcherUpdateArg"
    exit 0
}

releaseData=$(curl -s "https://api.github.com/repos/ketei/tagit-launcher/releases/latest")
releaseVersion=$(echo "$releaseData" | grep -o '"tag_name": ".*"' | cut -d '"' -f 4 | tr -cd '[:digit:].')
updateType=$(getUpdateType "$releaseVersion" "$localVersion")

# Launch immediately if up to date
test "$updateType" = "none" && {
    exec ./tagit -- --no-update "$launcherUpdateArg"
    exit 0
}

# Prompt user for a choice without any output to the terminal
choice() {
    while true; do
        saved_settings=$(stty -g)
        stty raw -echo

        _choice=$(dd bs=1 count=1 2>/dev/null | tr '[:upper:]' '[:lower:]')
        stty "$saved_settings"
        echo

        echo "$_choice" | grep -q "[$1]" && {
            echo "$_choice"
            break
        }
    done
}

# Only prompt if new version is actually newer
if test "$localVersion" != "0.0.0"; then

    echo "New version available: $releaseVersion"
    echo "Current version: $localVersion"
    echo "Would you like to update?"
    echo ""
    echo "(Y) Update Now"
    echo "(N) Launch Without Update"
    echo "(I) Ignore This Version"
    echo "(X) Never Update"

    response=$(choice "ynix")

    case $response in
    n) ;; # continue
    i) echo "$releaseVersion" >version ;;
    x) echo "x" >version ;;
    *) ;; # continue
    esac

    test "$response" != "y" && {
        exec ./tagit -- --no-update "$launcherUpdateArg"
        exit 0
    }
fi

# Determine if this is a full update or a partial update
if test "$updateType" = "major" || test "$updateType" = "minor"; then
    echo "Full update required"
    pattern="$kernel.*$arch|\.pck"
else
    echo "Partial update required"
    pattern="\.pck"
fi

# Download and install updated files
echo "$releaseData" | grep -o '"browser_download_url": ".*"' | cut -d '"' -f 4 | while read -r url; do
    filename=${url##*/} # Get everything after the last slash
    if echo "$filename" | grep -qE "$pattern"; then
        echo "Downloading $url"
        curl -s -L -O "$url"
    fi
done

mv -f "tagit.${kernel}.${arch}" tagit
chmod +x tagit

echo "$releaseVersion" >version
exec ./tagit -- --no-update "$launcherUpdateArg"
