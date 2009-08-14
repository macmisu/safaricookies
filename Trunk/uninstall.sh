#!/bin/sh

echo "Uninstalling Safari Cookies..."
rm -rf "/Library/InputManagers/Safari Cookies"
rm -f "$HOME/Library/Application Support/Safari Cookies"
rm -f "$HOME/Library/Logs/SafariCookies.log"

defaults delete com.apple.Safari SCremoveNonFavoritesWhenQuitting
defaults delete com.apple.Safari SCenableLogging
defaults delete com.apple.Safari SCcookieAcceptPolicy
defaults delete com.apple.Safari SCtabStateKey
defaults delete com.apple.Safari SCdontShowRemoveAllAlert
defaults delete com.apple.Safari SCdontShowExportAlert
defaults delete com.apple.Safari SCdontShowImportAlert