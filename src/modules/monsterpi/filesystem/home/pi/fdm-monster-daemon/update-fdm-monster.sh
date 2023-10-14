#!/bin/bash
: '
/**
 * Created by D. Zwart
 * Description: Performs all the steps to update FDM Monster
 * Last change: Update is running from the known server/daemon folders with push/popd
 * v2.0
 * 14th of October 2023
 */
'

# If you are logging in as pi user, you can skip the sudo su pi command.
# I decided to switch to the pi user with sudo su pi beforehand as I was logging in as david.
# Then I went to the folder /home/pi/fdm-monster-daemon/ with the command cd ~/fdm-monster-daemon.
# Then I ran the script I made sudo ./update-fdm-monster.sh.

# Step 0) Ensure we are root.
set -e
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root, this script must reinstall a service and, therefore, requires elevated permissions (root)"
  exit
fi

# Step 0b) Set the variables needed later
ts=6 # total steps
org=fdm-monster
repo=fdm-monster
server_path="/home/pi/fdm-monster/"
daemon_path="/home/pi/fdm-monster-daemon/"
dist_zips_path="/home/pi/fdm-monster/dist-zips/"
dist_active_path="/home/pi/fdm-monster/dist/"
dist_prefix="dist-server"
repo_url="https://github.com/${org}/${repo}"

# Step 1) Check latest release of FDM Monster
tags="$(git ls-remote --sort=-v:refname --tags $repo_url | awk -F"/" '{print $NF}')"
newest_tag=$(echo "$tags" | sort -V | tail -1)

# Check if the tag contains "-rc" or "-unstable"
if [[ $newest_tag == *"-rc"* || $newest_tag == *"-unstable"* ]]; then
    echo "Newest tag is $newest_tag which seems to be a release candidate or unstable version."
    echo "Do you want to install this tag(Y) or install the latest stable(N) (Y/N)?"
    read -r response

    if [[ $response == "Y" || $response == "y" ]]; then
        # Install the tag
        echo "[1/${ts}] Installing tag $newest_tag"
    else
        # Search for the latest stable tag in x.y.z format
        newest_tag=$(echo "$tags" | grep -E "^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$" | sort -V | tail -1)
        echo "[1/${ts}] Installing latest stable tag: $newest_tag"
    fi
else
    echo "[1/${ts}] Installing latest stable tag: $newest_tag"
fi

# Step 2) Temporarily stop FDM Monster Daemon
# `curl 0.0.0.0:4000` will fail to connect, you can test it if you want to be sure
echo "[2/${ts}] Stopping FDM Monster before an update"
pushd "${daemon_path}"
npm run uninstall

# Step 3) Switch the latest FDM Monster to this tag
pushd "${server_path}"
echo "[3/${ts}] Finding the latest version of FDM Monster from Github"

## Step 3b
echo "[3/${ts}] Ensuring folders are created"
mkdir -p $dist_active_path
mkdir -p $dist_zips_path
tag=$(gh release view --repo https://github.com/$org/$repo --json tagName --jq .tagName)
echo "[3/${ts}] Downloading version version ${tag} of FDM Monster from Github"
gh release download $tag --clobber --repo https://github.com/$org/$repo --dir "${dist_zips_path}" --clobber

## CLEAR OLD DIST FOLDER
echo "[3/${ts}] Clearing old dist folder"
rm -fr $dist_active_path
mkdir -p $dist_active_path

## EXTRACT NEW DIST ZIP
echo "[3/${ts}] Extracting new dist zip to ${dist_active_path}"
7z x "${dist_zips_path}/${dist_prefix}-${tag}.zip" -o"${dist_active_path}"

# Step 4a) Ensure yarn is new, (optional)
# npm i -g yarn

# Step 4) Ensure the required packages are present with yarn (which is already installed, we're just keeping it fresh)
echo "[4/${ts}] Updating the necessary modules of FDM Monster"
yarn install --production --pure-lockfile

# Step 5) Run the service
popd
echo "[5/${ts}] Installing FDM Monster version ${newest_tag}"
npm run install

echo "[6/${ts}] Upgrading FDM Monster completed, you can verify with 'curl http://0.0.0.0:4000'"
popd
