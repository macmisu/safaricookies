I have the project setup so that when you compile it will put a working copy into your Input Managers folder:
/Library/Input Managers/

you will need to authenticate before running the installer, else it will fail.

I just use this command:
sudo rm -R /Library/InputManagers/Safari\ Cookies


Fixed in this release:
---------------------------------------------------------
-added Search
-added Spanish localization
-fixed console error [NSCFArray objectAtIndex:]: index (3) beyond bounds (3)
-redundant code cleanup
-UI fixes
---------------------------------------------------------


Still to do:
---------------------------------------------------------
-fix bug with adobe apps (webkit)
-Snow Leopard support.
-add sparkle
---------------------------------------------------------
