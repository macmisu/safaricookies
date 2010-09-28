#!/bin/sh

echo "Uninstalling Safari Cookies..."
rm -r "/Library/Application Support/SIMBL/Plugins/Safari Cookies.bundle"
rm -rf "$HOME/Library/Application Support/Safari Cookies"

defaults delete com.sweetpproductions.SafariCookies