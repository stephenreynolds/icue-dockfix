# icue-dockfix

Makes Corsair iCUE (5.x, macOS) drop its Dock icon when you close its window,
like other menu-bar apps. Reopening the window brings the icon back; a
minimized window keeps it.

iCUE already shows its Dock icon when the window opens
(`MacOSHelpers::setOsXUiElementsVisible(true)`), but never hides it again on
close. `DockFix.m` is a small dylib that fills in that half: when the last
iCUE window closes, it switches the app to the Accessory activation policy.

## How it's loaded

iCUE is signed with `allow-dyld-environment-variables` and
`disable-library-validation`, and its `Info.plist` is not bound to the code
signature. `install.sh` adds `LSEnvironment.DYLD_INSERT_LIBRARIES` to that
plist, pointing at `/Library/Application Support/iCUE-DockFix/libDockFix.dylib`.
The iCUE binary and Corsair's signature are not touched.

## Usage

```sh
./install.sh     # build, install, patch Info.plist, restart iCUE (asks for sudo)
./uninstall.sh   # remove the plist key and the dylib
```

Re-run `install.sh` after every iCUE update: updates replace `Info.plist`.

Don't delete the installed dylib by hand while the plist key is in place —
iCUE will fail to launch. Use `uninstall.sh`.

Note: `codesign --verify` reports "invalid resource directory" on iCUE even
when unmodified (Corsair ships it without a resource seal); that is expected.
