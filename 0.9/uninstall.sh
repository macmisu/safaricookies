#!/bin/sh

echo "Uninstalling Safari Cookies..."
rm -rf "/Library/InputManagers/Safari Cookies"
rm -rf "$HOME/Library/Application Support/Safari Cookies"
rm -f "$HOME/Library/Logs/SafariCookies.log"
rm -f "$HOME/Library/Preferences/com.sweetpproductions.SafariCookies.plist"

defaults delete com.apple.Safari SCremoveNonFavoritesWhenQuitting
defaults delete com.apple.Safari SCenableLogging
defaults delete com.apple.Safari SCautomaticUpdating
defaults delete com.apple.Safari SCcookieAcceptPolicy
defaults delete com.apple.Safari SCtabState
defaults delete com.apple.Safari SCdontShowRemoveAllAlert
defaults delete com.apple.Safari SCdontShowExportAlert
defaults delete com.apple.Safari SCdontShowImportAlert
defaults delete com.apple.Safari SCdontShowImportFromBookmarksAlert
defaults delete com.apple.Safari SCdontShowImportFromTopSitesAlert
defaults delete com.apple.Safari SCremoveFlashCookiesWhenQuitting