#import "GameDataPickerController.h"

#import "ios.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface GameDataPickerController ()
@property UIWindow *window;
@property UIDocumentPickerViewController *picker;
@property UIAlertController *progressAlert;
@end

@implementation GameDataPickerController

- (instancetype)initWithWindow:(UIWindow *)window {
    self = [super init];
    if (self) {
        self.window = window;
    }
    return self;
}

- (void)showInstructions {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Game Data Required"
                                   message:@"CaesarPad needs your Caesar III data. Select the folder that directly contains c3.eng and c3_model.txt. The folder name does not matter."
                                   preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"Choose Folder"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
        [self showDocumentPicker];
    }];

    [alert addAction:defaultAction];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)showDocumentPicker {
    self.picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder]];
    self.picker.delegate = self;
    [self.window.rootViewController presentViewController:self.picker animated:YES completion:nil];
}

- (void)finishWithGameDataDirectory:(NSURL *)gameDataDirectory {
    char path[300];
    [gameDataDirectory.path getFileSystemRepresentation:path maxLength:sizeof(path)];
    c3_path_chosen(path);
}

- (void)showImportError:(NSError *)error {
    NSString *message = [NSString stringWithFormat:
        @"Could not copy the game data.\n\n%@\n\n"
         @"If On My iPad > CaesarPad > C3 already contains your files, close and reopen CaesarPad.",
        error.localizedDescription];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Import Failed"
                                   message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"Choose Another Folder"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
        [self showDocumentPicker];
    }];

    [alert addAction:defaultAction];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *importDirectory = urls.firstObject;
    if (!importDirectory) {
        [controller dismissViewControllerAnimated:YES completion:^{
            [self showDocumentPicker];
        }];
        return;
    }

    BOOL hasSecurityScopedAccess = [importDirectory startAccessingSecurityScopedResource];
    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                         inDomains:NSUserDomainMask] lastObject];
    NSURL *gameDataDirectory = [documentsDirectory URLByAppendingPathComponent:@"C3" isDirectory:YES];
    NSString *importPath = [importDirectory.URLByResolvingSymlinksInPath.path stringByStandardizingPath];
    NSString *gameDataPath = [gameDataDirectory.URLByResolvingSymlinksInPath.path stringByStandardizingPath];

    NSString *gameDataPrefix = [gameDataPath stringByAppendingString:@"/"];
    BOOL usesExistingGameData = [importPath isEqualToString:gameDataPath] ||
        [importPath hasPrefix:gameDataPrefix];

    if (usesExistingGameData) {
        if (hasSecurityScopedAccess) {
            [importDirectory stopAccessingSecurityScopedResource];
        }
        [controller dismissViewControllerAnimated:YES completion:^{
            [self finishWithGameDataDirectory:gameDataDirectory];
        }];
        return;
    }

    [controller dismissViewControllerAnimated:YES completion:^{
        self.progressAlert = [UIAlertController alertControllerWithTitle:@"Importing Game Data"
                                  message:@"Copying your Caesar III files. This can take a minute; please keep CaesarPad open."
                                  preferredStyle:UIAlertControllerStyleAlert];
        [self.window.rootViewController presentViewController:self.progressAlert animated:YES completion:^{
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                NSError *error = nil;
                BOOL success = [[NSFileManager new] copyItemAtURL:importDirectory
                                                            toURL:gameDataDirectory
                                                            error:&error];
                if (hasSecurityScopedAccess) {
                    [importDirectory stopAccessingSecurityScopedResource];
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.progressAlert dismissViewControllerAnimated:YES completion:^{
                        self.progressAlert = nil;
                        if (success) {
                            NSLog(@"Files copied to: %@", gameDataDirectory);
                            [self finishWithGameDataDirectory:gameDataDirectory];
                        } else {
                            NSLog(@"Error copying data files: %@", error);
                            [self showImportError:error];
                        }
                    }];
                });
            });
        }];
    }];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    [self showInstructions];
}

@end
