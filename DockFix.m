// DockFix: hides iCUE's Dock icon when its main window is closed.
//
// iCUE already promotes itself to a regular (Dock) app when its window opens
// (MacOSHelpers::setOsXUiElementsVisible(true) from UI::CueUi::show), but
// never demotes itself again when the window closes to the menu bar. This
// library fills in that missing half: when the last iCUE window goes away,
// the app switches to the Accessory policy (menu bar icon only, no Dock icon).
//
// Loaded via DYLD_INSERT_LIBRARIES. iCUE is signed with
// allow-dyld-environment-variables + disable-library-validation, so the
// original binary and signature are left untouched.

#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static BOOL gHideCheckScheduled = NO;
static BOOL gSawWindow = NO;
static int gEmptyTicks = 0;

// iCUE's real UI windows are Qt top-levels (QNSWindow). System helper windows
// (status item, text input, menus) and Qt popups/panels don't count.
static BOOL DFIsUserWindow(NSWindow *w) {
    if (w.level != NSNormalWindowLevel) return NO;
    if (![NSStringFromClass([w class]) isEqualToString:@"QNSWindow"]) return NO;
    if (NSWidth(w.frame) < 50 || NSHeight(w.frame) < 50) return NO;
    // A minimized window lives in the Dock, so the icon has to stay.
    return w.isMiniaturized || w.isVisible;
}

static BOOL DFHasUserWindow(void) {
    for (NSWindow *w in NSApp.windows) {
        if (DFIsUserWindow(w)) return YES;
    }
    return NO;
}

static void DFHideIfNoWindows(void) {
    if (DFHasUserWindow()) return;
    if (NSApp.activationPolicy != NSApplicationActivationPolicyRegular) return;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

static void DFScheduleHideCheck(NSWindow *w) {
    if (![NSStringFromClass([w class]) isEqualToString:@"QNSWindow"]) return;
    if (gHideCheckScheduled) return;
    gHideCheckScheduled = YES;
    // Short delay so a hide-then-show (e.g. Qt recreating a window) doesn't flicker the Dock.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        gHideCheckScheduled = NO;
        DFHideIfNoWindows();
    });
}

static void DFHookHide(SEL sel) {
    Method m = class_getInstanceMethod([NSWindow class], sel);
    if (!m) return;
    IMP orig = method_getImplementation(m);
    IMP repl;
    if (strchr(sel_getName(sel), ':')) {
        repl = imp_implementationWithBlock(^(NSWindow *self, id arg) {
            ((void (*)(id, SEL, id))orig)(self, sel, arg);
            DFScheduleHideCheck(self);
        });
    } else {
        repl = imp_implementationWithBlock(^(NSWindow *self) {
            ((void (*)(id, SEL))orig)(self, sel);
            DFScheduleHideCheck(self);
        });
    }
    method_setImplementation(m, repl);
}

__attribute__((constructor))
static void DFInit(void) {
    // Don't leak into child processes (WebEngine helpers, crashpad, etc.).
    unsetenv("DYLD_INSERT_LIBRARIES");
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.corsair.cue.main"]) return;

    DFHookHide(@selector(orderOut:));
    DFHookHide(@selector(close));
    DFHookHide(@selector(miniaturize:));

    // Safety net for hide paths that bypass the hooks above: if a window was
    // open and none has been for two ticks, drop the Dock icon.
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *t) {
            if (DFHasUserWindow()) {
                gSawWindow = YES;
                gEmptyTicks = 0;
            } else if (gSawWindow && ++gEmptyTicks >= 2) {
                gSawWindow = NO;
                DFHideIfNoWindows();
            }
        }];
    });
}
