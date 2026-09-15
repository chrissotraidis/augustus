#import "ios.h"

#import "GameDataPickerController.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include "game/state.h"

#define GAME_PATH_MAX 300
static int has_directory;
static char path[GAME_PATH_MAX];
static UIWindow *window = nil;
static UIWindow *alertwindow = nil;

@interface CaesarPadPauseTarget : NSObject
- (void)togglePause;
- (void)showControls;
@end

static UIButton *pauseButton = nil;
static UIButton *helpButton = nil;

@implementation CaesarPadPauseTarget

- (void)togglePause {
    game_state_toggle_paused();
    BOOL paused = game_state_is_paused();
    pauseButton.accessibilityValue = paused ? @"Paused" : @"Running";
    [pauseButton setImage:[UIImage systemImageNamed:paused ? @"play.fill" : @"pause.fill"]
                 forState:UIControlStateNormal];
}

- (void)showControls {
    if (alertwindow) {
        return;
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"CaesarPad Controls"
        message:@"Tap: select buildings and controls\nDrag one finger: pan the map\nDrag two fingers together: pan the map\nPinch: zoom\nLong press or two-finger tap: inspect or cancel\n\nCaesar III is a city builder, not an RTS. Walkers move automatically and cannot be group-selected; military legions are ordered individually."
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

@end

@interface CaesarPadCanvasAccessibilityElement : UIAccessibilityElement
@end

@implementation CaesarPadCanvasAccessibilityElement

- (CGRect)accessibilityFrameInContainerSpace {
    return ((UIView *)self.accessibilityContainer).bounds;
}

@end

static CaesarPadPauseTarget *pauseTarget = nil;
static UIAccessibilityElement *canvasAccessibility = nil;
static BOOL lifecycleResumed = NO;

void ios_install_pause_button(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (pauseButton) {
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

        pauseTarget = [CaesarPadPauseTarget new];
        pauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
        pauseButton.translatesAutoresizingMaskIntoConstraints = NO;
        pauseButton.accessibilityIdentifier = @"caesarpad.pause";
        pauseButton.accessibilityLabel = @"Pause or resume game";
        pauseButton.accessibilityValue = lifecycleResumed ? @"Running, lifecycle autosave resumed" : @"Running";
        pauseButton.tintColor = UIColor.whiteColor;
        pauseButton.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.65];
        pauseButton.layer.cornerRadius = 10;
        [pauseButton setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
        [pauseButton addTarget:pauseTarget action:@selector(togglePause) forControlEvents:UIControlEventTouchUpInside];

        helpButton = [UIButton buttonWithType:UIButtonTypeSystem];
        helpButton.translatesAutoresizingMaskIntoConstraints = NO;
        helpButton.accessibilityIdentifier = @"caesarpad.help";
        helpButton.accessibilityLabel = @"Show CaesarPad controls";
        helpButton.tintColor = UIColor.whiteColor;
        helpButton.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.65];
        helpButton.layer.cornerRadius = 10;
        [helpButton setImage:[UIImage systemImageNamed:@"questionmark"] forState:UIControlStateNormal];
        [helpButton addTarget:pauseTarget action:@selector(showControls) forControlEvents:UIControlEventTouchUpInside];

        [gameWindow addSubview:pauseButton];
        [gameWindow addSubview:helpButton];
        canvasAccessibility = [[CaesarPadCanvasAccessibilityElement alloc] initWithAccessibilityContainer:gameWindow];
        canvasAccessibility.accessibilityIdentifier = @"caesarpad.canvas";
        canvasAccessibility.accessibilityLabel = @"Caesar III game canvas";
        canvasAccessibility.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction;
        gameWindow.accessibilityElements = @[pauseButton, helpButton, canvasAccessibility];
        [NSLayoutConstraint activateConstraints:@[
            [pauseButton.leadingAnchor constraintEqualToAnchor:gameWindow.safeAreaLayoutGuide.leadingAnchor constant:12],
            [pauseButton.bottomAnchor constraintEqualToAnchor:gameWindow.safeAreaLayoutGuide.bottomAnchor constant:-12],
            [pauseButton.widthAnchor constraintEqualToConstant:48],
            [pauseButton.heightAnchor constraintEqualToConstant:48],
            [helpButton.leadingAnchor constraintEqualToAnchor:pauseButton.trailingAnchor constant:8],
            [helpButton.bottomAnchor constraintEqualToAnchor:pauseButton.bottomAnchor],
            [helpButton.widthAnchor constraintEqualToConstant:48],
            [helpButton.heightAnchor constraintEqualToConstant:48],
        ]];
    });
}

void ios_mark_lifecycle_resumed(void) {
    lifecycleResumed = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        pauseButton.accessibilityValue = @"Running, lifecycle autosave resumed";
    });
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
