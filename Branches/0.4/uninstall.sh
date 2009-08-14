#!/bin/sh

echo "Uninstalling Safari Cookies..."
rm -rf "/Library/InputManagers/Safari Cookies"
rm -f "$HOME/Library/Logs/SafariCookies.log"
defaults delete com.apple.Safari SCremoveNonFavoritesWhenQuitting
defaults delete com.apple.Safari SCenableLogging
defaults delete com.apple.Safari SCcookieAcceptPolicy
defaults delete com.apple.Safari SCacceptCookieDomains
defaults delete com.apple.Safari SCTabStateKey
defaults delete com.apple.Safari SCDontShowAlert
defaults delete com.apple.Safari SCDontShowExportAlert
defaults delete com.apple.Safari SCDontShowImportAlert