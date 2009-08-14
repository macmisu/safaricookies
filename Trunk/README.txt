I have the project setup so that when you compile it will put a working copy into your Input Managers folder:
/Library/Input Managers/

you will need to authenticate before running the installer, else it will fail.

I just use this command:
sudo rm -R /Library/InputManagers/Safari\ Cookies


Fixed in this release:
---------------------------------------------------------
French localization corrections
---------------------------------------------------------


Still to do:
---------------------------------------------------------
-fix bug where if there are no favorites checked - checking favorites within a search/contextual-menu is not honored

-Snow Leopard support
-add sparkle
-fix bug with adobe apps (webkit)
---------------------------------------------------------
