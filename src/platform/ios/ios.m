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
@end

static UIButton *pauseButton = nil;

@implementation CaesarPadPauseTarget

- (void)togglePause {
    game_state_toggle_paused();
    BOOL paused = game_state_is_paused();
    pauseButton.accessibilityValue = paused ? @"Paused" : @"Running";
    [pauseButton setImage:[UIImage systemImageNamed:paused ? @"play.fill" : @"pause.fill"]
                 forState:UIControlStateNormal];
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
        pauseButton.accessibilityValue = @"Running";
        pauseButton.tintColor = UIColor.whiteColor;
        pauseButton.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.65];
        pauseButton.layer.cornerRadius = 10;
        [pauseButton setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
        [pauseButton addTarget:pauseTarget action:@selector(togglePause) forControlEvents:UIControlEventTouchUpInside];

        [gameWindow addSubview:pauseButton];
        canvasAccessibility = [[CaesarPadCanvasAccessibilityElement alloc] initWithAccessibilityContainer:gameWindow];
        canvasAccessibility.accessibilityIdentifier = @"caesarpad.canvas";
        canvasAccessibility.accessibilityLabel = @"Caesar III game canvas";
        canvasAccessibility.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction;
        gameWindow.accessibilityElements = @[pauseButton, canvasAccessibility];
        [NSLayoutConstraint activateConstraints:@[
            [pauseButton.leadingAnchor constraintEqualToAnchor:gameWindow.safeAreaLayoutGuide.leadingAnchor constant:12],
            [pauseButton.bottomAnchor constraintEqualToAnchor:gameWindow.safeAreaLayoutGuide.bottomAnchor constant:-12],
            [pauseButton.widthAnchor constraintEqualToConstant:48],
            [pauseButton.heightAnchor constraintEqualToConstant:48],
        ]];
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
