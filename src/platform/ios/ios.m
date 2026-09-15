#import "ios.h"

#import "GameDataPickerController.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include "input/touch.h"

#define GAME_PATH_MAX 300
static int has_directory;
static char path[GAME_PATH_MAX];
static UIWindow *window = nil;
static UIWindow *alertwindow = nil;

@interface CaesarPadControlsTarget : NSObject
- (void)showControls;
- (void)togglePencilMode;
@end

static UIButton *helpButton = nil;
static UIButton *pencilButton = nil;
static BOOL pencilMode = NO;

static void updatePencilButton(void) {
    pencilButton.accessibilityValue = pencilMode ? @"On" : @"Off, traditional touch controls";
    [pencilButton setTitle:pencilMode ? @"On" : @"Off" forState:UIControlStateNormal];
    pencilButton.backgroundColor = pencilMode ?
        [UIColor.systemBlueColor colorWithAlphaComponent:0.85] :
        [UIColor.blackColor colorWithAlphaComponent:0.65];
}

@implementation CaesarPadControlsTarget

- (void)showControls {
    if (alertwindow) {
        return;
    }

    NSString *message = pencilMode ?
        @"PENCIL MODE\nPencil: select, inspect, and place\nDrag one finger: pan only\nPinch: zoom\n\nFinger taps cannot change the city while Pencil mode is on. Tap the blue Pencil control to return to traditional touch controls.\n\nUse the Game speed panel at bottom-right to pause or resume. Caesar III is a city builder, not an RTS: walkers move automatically and cannot be group-selected; military legions are ordered individually." :
        @"TRADITIONAL TOUCH\nTap: select buildings and controls\nDrag one finger: pan the map\nDrag two fingers together: pan the map\nPinch: zoom\nLong press or two-finger tap: inspect or cancel\n\nTap the Pencil control for precise Pencil interaction with finger-only navigation.\n\nUse the Game speed panel at bottom-right to pause or resume. Caesar III is a city builder, not an RTS: walkers move automatically and cannot be group-selected; military legions are ordered individually.";
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"CaesarPad Controls"
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    UIWindow *gameWindow = helpButton.window;
    [alert addAction:[UIAlertAction actionWithTitle:@"Got it" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        alertwindow.hidden = YES;
        alertwindow = nil;
        [gameWindow makeKeyWindow];
    }]];

    alertwindow = [[UIWindow alloc] initWithWindowScene:gameWindow.windowScene];
    alertwindow.rootViewController = [UIViewController new];
    alertwindow.windowLevel = UIWindowLevelAlert;
    [alertwindow makeKeyAndVisible];
    [alertwindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)togglePencilMode {
    pencilMode = !pencilMode;
    [[NSUserDefaults standardUserDefaults] setBool:pencilMode forKey:@"CaesarPadPencilMode"];
    touch_set_pencil_mode(pencilMode);
    updatePencilButton();
}

@end

@interface CaesarPadCanvasAccessibilityElement : UIAccessibilityElement
@end

@implementation CaesarPadCanvasAccessibilityElement

- (CGRect)accessibilityFrameInContainerSpace {
    return ((UIView *)self.accessibilityContainer).bounds;
}

@end

static CaesarPadControlsTarget *controlsTarget = nil;
static UIAccessibilityElement *canvasAccessibility = nil;

void ios_install_pause_button(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (helpButton) {
            return;
        }

        UIWindow *gameWindow = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
                if (!candidate.hidden && candidate.windowLevel == UIWindowLevelNormal) {
                    gameWindow = candidate;
                    break;
                }
            }
            if (gameWindow) {
                break;
            }
        }
        if (!gameWindow.rootViewController.view) {
            return;
        }

        controlsTarget = [CaesarPadControlsTarget new];
        pencilMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"CaesarPadPencilMode"];
        touch_set_pencil_mode(pencilMode);

        helpButton = [UIButton buttonWithType:UIButtonTypeSystem];
        helpButton.translatesAutoresizingMaskIntoConstraints = NO;
        helpButton.accessibilityIdentifier = @"caesarpad.help";
        helpButton.accessibilityLabel = @"Show CaesarPad controls";
        helpButton.tintColor = UIColor.whiteColor;
        helpButton.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.65];
        helpButton.layer.cornerRadius = 6;
        [helpButton setImage:[UIImage systemImageNamed:@"questionmark"] forState:UIControlStateNormal];
        [helpButton addTarget:controlsTarget action:@selector(showControls) forControlEvents:UIControlEventTouchUpInside];

        pencilButton = [UIButton buttonWithType:UIButtonTypeSystem];
        pencilButton.translatesAutoresizingMaskIntoConstraints = NO;
        pencilButton.accessibilityIdentifier = @"caesarpad.pencil-mode";
        pencilButton.accessibilityLabel = @"Apple Pencil controls";
        pencilButton.tintColor = UIColor.whiteColor;
        [pencilButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        pencilButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        pencilButton.layer.cornerRadius = 6;
        [pencilButton setImage:[UIImage systemImageNamed:@"pencil"] forState:UIControlStateNormal];
        [pencilButton addTarget:controlsTarget action:@selector(togglePencilMode) forControlEvents:UIControlEventTouchUpInside];
        updatePencilButton();

        [gameWindow addSubview:pencilButton];
        [gameWindow addSubview:helpButton];
        canvasAccessibility = [[CaesarPadCanvasAccessibilityElement alloc] initWithAccessibilityContainer:gameWindow];
        canvasAccessibility.accessibilityIdentifier = @"caesarpad.canvas";
        canvasAccessibility.accessibilityLabel = @"Caesar III game canvas";
        canvasAccessibility.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction;
        gameWindow.accessibilityElements = @[pencilButton, helpButton, canvasAccessibility];
        [NSLayoutConstraint activateConstraints:@[
            [pencilButton.topAnchor constraintEqualToAnchor:gameWindow.safeAreaLayoutGuide.topAnchor constant:2],
            [pencilButton.widthAnchor constraintEqualToConstant:52],
            [pencilButton.heightAnchor constraintEqualToConstant:28],
            [helpButton.leadingAnchor constraintEqualToAnchor:pencilButton.trailingAnchor constant:3],
            [helpButton.topAnchor constraintEqualToAnchor:pencilButton.topAnchor],
            [helpButton.trailingAnchor constraintEqualToAnchor:gameWindow.safeAreaLayoutGuide.trailingAnchor constant:-8],
            [helpButton.widthAnchor constraintEqualToConstant:28],
            [helpButton.heightAnchor constraintEqualToConstant:28],
        ]];
    });
}

void ios_mark_lifecycle_resumed(void) {
}

void c3_path_chosen(char *new_path) {
    unsigned long len = strlen(new_path);
    snprintf(path, GAME_PATH_MAX, "%s", new_path);
    has_directory = true;
}

const char *ios_get_base_path(void) {
    NSURL *gameDataDirectory = [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:@"C3" isDirectory:YES];
    
    [gameDataDirectory.path getFileSystemRepresentation:path maxLength:300];
    
    return path;
}

const char *ios_get_lifecycle_autosave_path(void) {
    static char autosavePath[GAME_PATH_MAX];
    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *autosaveURL = [documentsDirectory URLByAppendingPathComponent:@"caesarpad-autosave.svx"];
    [autosaveURL.path getFileSystemRepresentation:autosavePath maxLength:GAME_PATH_MAX];
    return autosavePath;
}

const char *ios_show_c3_path_dialog(int again)
{
    if (window == nil) {
        window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.rootViewController = [UIViewController new];
        window.windowLevel = UIWindowLevelAlert;

        [window makeKeyAndVisible];
    }
    
    
    GameDataPickerController *controller = [[GameDataPickerController alloc] initWithWindow: window];
    [controller showInstructions];
    
    
    while (!has_directory) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
    }

    if (window) {
        window.hidden = YES;
    }
    
    return path;
}
