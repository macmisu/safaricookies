I have the project setup so that when you compile it will put a working copy into your Input Managers folder:
/Library/Input Managers/

you will need to authenticate before running the installer, else it will fail.

I just use this command:
sudo rm -R /Library/InputManagers/Safari\ Cookies


NSLog(@"bookmarks %@", bookmarksArray);


Fixed in this release:
---------------------------------------------------------
Added Sparkle automatic updating
Added "Check All", "UnCheck All" as Favorites options
Added "Import Favorites from Safari Bookmarks"
Added "Import Favorites from Safari TopSites"

Moved all Favorites management to contextual menu

"About" panel corrections
French localization corrections
UI tweaks

Fixed bug where if there are no favorites checked - checking favorites within a search/contextual-menu is not honored
Fixed sort order and other issues for some special case cookies
Fixed display of IP addresses
Fixed default settings


Built using XCode 3.2
Replaced some deprecated functions
---------------------------------------------------------


Still to do:
---------------------------------------------------------
-64-bit Snow Leopard support
-update poseAsClass methods to use MethodSwizzle
---------------------------------------------------------
