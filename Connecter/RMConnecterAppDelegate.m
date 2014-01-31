//
//    RMiTunesConnecterAppDelegate.m
//    Connecter
//
//    Created by Nik Fletcher on 31/01/2014.
//
//    Copyright (c) 2014 Nik Fletcher, Realmac Software
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.
//

#import "RMConnecterAppDelegate.h"

@implementation RMConnecterAppDelegate

NSString * const DefaultiTunesTransporterPath = @"/Applications/Xcode.app/Contents/Applications/Application Loader.app/Contents/MacOS/itms/bin/iTMSTransporter";

NSString * const LastPackageLocationDefaultsKey = @"lastPackageLocation";

#pragma mark App Setup

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    @autoreleasepool {
		NSDictionary *registrationDefaults = @{LastPackageLocationDefaultsKey : @"~/Desktop"};
		[[NSUserDefaults standardUserDefaults] registerDefaults:registrationDefaults];

	}
    if (![self transporterIsInstalled]) {
        
        [[self statusTextField] setStringValue:NSLocalizedString(@"Please install iTunes Transporter", @"Status Field Install Transporter String")];
        [self setCredentialEntryAvailability:NO];
        [self setTransporterInteractionAvailability:NO];
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
        [alert addButtonWithTitle:NSLocalizedString(@"Get Xcode", "Transporter Missing Alert Get Xcode Button Label")];
        [alert setMessageText:NSLocalizedString(@"Unable to Locate iTMSTransporter", @"")];
        [alert setInformativeText:NSLocalizedString(@"Connecter requires the iTMSTransporter binary to be installed. Please install Xcode from the Mac App Store.", @"")];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
    } else {
        [[self statusTextField] setStringValue:NSLocalizedString(@"Please enter your iTunes Connect credentials…", @"")];
        [self setTransporterInteractionAvailability:NO];
    };
}

#pragma mark IBActions

- (IBAction)chooseiTunesPackage:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanCreateDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowedFileTypes:@[@"itmsp"]];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString * filePath = [defaults stringForKey:LastPackageLocationDefaultsKey];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    [openPanel setDirectoryURL:fileURL];
    
    [openPanel beginSheetModalForWindow:_window
                      completionHandler:^(NSInteger result) {
                          if (result == NSFileHandlingPanelCancelButton) {
                              return;
                          }
                          [[self logView] setString:@""];
                          NSURL *selectedPackageURL = [openPanel URL];
                          NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                          [defaults setObject:selectedPackageURL.path forKey:LastPackageLocationDefaultsKey];
                          switch ([sender tag]) {
                              case 1:
                                  [self verifyiTunesPackageAtURL:selectedPackageURL];
                                  [[self statusTextField] setStringValue:[NSString stringWithFormat:@"Verifying iTunes Package: %@", selectedPackageURL.path]];
                                  break;
                              case 2:
                                  [self submitPackageAtURL:selectedPackageURL];
                                  [[self statusTextField] setStringValue:[NSString stringWithFormat:@"Submitting iTunes Package: %@", selectedPackageURL.path]];
                                  break;
                              default:
                                  break;
                          }
                      }];
}

- (IBAction)selectLocationForDownloadedMetadata:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanCreateDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    
    NSString * filePath = @"~/Desktop";
    filePath = [filePath stringByExpandingTildeInPath];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    [openPanel setDirectoryURL:fileURL];
    
    [openPanel beginSheetModalForWindow:_window
                      completionHandler:^(NSInteger result) {
                          if (result == NSFileHandlingPanelCancelButton) {
                              return;
                          }
                          [[self logView] setString:@""];
                          NSURL *selectedPackageURL = [openPanel URL];
                          [[self statusTextField] setStringValue:[NSString stringWithFormat:@"Retrieving package from iTunes Connect. Metadata will be downloaded to %@", selectedPackageURL.path]];
                          [self lookupMetadataAndPlaceInPackageAtURL:selectedPackageURL];
                      }];
}

#pragma mark -
#pragma mark iTunes Connect Interaction

- (void)lookupMetadataAndPlaceInPackageAtURL:(NSURL *)PackageURL {
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperationWithBlock:^(void) {
        [self shouldShowAndAnimateActivityIndicator:YES];
        [self setTransporterInteractionAvailability:NO];
        [self setCredentialEntryAvailability:NO];
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:DefaultiTunesTransporterPath];
        
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];
        NSFileHandle *file = [pipe fileHandleForReading];
        
        [task setArguments:@[@"-m", @"lookupMetadata", @"-u", self.iTunesConnectUsernameField.stringValue, @"-p", self.iTunesConnectPasswordField.stringValue, @"-vendor_id", self.iTunesConnectAppSKUField.stringValue, @"-destination", PackageURL]];
        [task launch];
        
        NSData *data = [file readDataToEndOfFile];
        NSString *string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        [[self logView] setString:string];
        [self setCredentialEntryAvailability:YES];
        [self setTransporterInteractionAvailability:YES];
        [self shouldShowAndAnimateActivityIndicator:NO];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[PackageURL]];
    }];
}

- (void)verifyiTunesPackageAtURL:(NSURL *)PackageURL {
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperationWithBlock:^(void) {
        [self shouldShowAndAnimateActivityIndicator:YES];
        [self setTransporterInteractionAvailability:NO];
        [self setCredentialEntryAvailability:NO];
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:DefaultiTunesTransporterPath];
        
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];
        NSFileHandle *file = [pipe fileHandleForReading];
        
        [task setArguments:@[@"-m", @"verify",  @"-f", PackageURL, @"-u", self.iTunesConnectUsernameField.stringValue, @"-p", self.iTunesConnectPasswordField.stringValue]];
        [task launch];
        
        NSData *data = [file readDataToEndOfFile];
        NSString *string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        [[self statusTextField] setStringValue:NSLocalizedString(@"Finished", "Finished Interacting with iTunes Connect Strings")];
        [[self logView] setString:string];
        [self setCredentialEntryAvailability:YES];
        [self setTransporterInteractionAvailability:YES];
        [self shouldShowAndAnimateActivityIndicator:NO];
    }];
}

- (void)submitPackageAtURL:(NSURL *)PackageURL {
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperationWithBlock:^(void) {
        [self shouldShowAndAnimateActivityIndicator:YES];
        [self setTransporterInteractionAvailability:NO];
        [self setCredentialEntryAvailability:NO];
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:DefaultiTunesTransporterPath];
        
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];
        NSFileHandle *file = [pipe fileHandleForReading];
        
        [task setArguments:@[@"-m", @"upload",  @"-f", PackageURL, @"-u", self.iTunesConnectUsernameField.stringValue, @"-p", self.iTunesConnectPasswordField.stringValue]];
        [task launch];
        
        NSData *data = [file readDataToEndOfFile];
        NSString *string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        [[self logView] setString:string];
        [[self statusTextField] setStringValue:NSLocalizedString(@"Finished", "Finished Interacting with iTunes Connect Strings")];
        [self setCredentialEntryAvailability:YES];
        [self setTransporterInteractionAvailability:YES];
        [self shouldShowAndAnimateActivityIndicator:NO];
    }];
}

#pragma mark -
#pragma mark Transporter Preflighting

- (BOOL)transporterIsInstalled {
    [[self statusTextField] setStringValue:@"Checking for iTunes Transporter…"];
    return ([[NSFileManager defaultManager] fileExistsAtPath:DefaultiTunesTransporterPath]);
}

- (void)setCredentialEntryAvailability:(BOOL)b {
    [[self iTunesConnectPasswordField] setEnabled:b];
    [[self iTunesConnectUsernameField] setEnabled:b];
}

- (void)setTransporterInteractionAvailability:(BOOL)b {
    [[self submitLocalPackageToiTunesConnectButton] setEnabled:b];
    [[self verifyLocalPackageButton] setEnabled:b];
    [[self iTunesConnectAppSKUField] setEnabled:b];
    if ([self.iTunesConnectAppSKUField.stringValue length] > 0) {
        [[self downloadPackageFromiTunesConnectButton] setEnabled:b];
    }
}

- (void)shouldShowAndAnimateActivityIndicator:(BOOL)b {
    switch (b) {
        case YES:
            [_activityQueueProgressIndicator setHidden:NO];
            [_activityQueueProgressIndicator startAnimation:self];
            break;
        default:
            [_activityQueueProgressIndicator setHidden:YES];
            
            [_activityQueueProgressIndicator stopAnimation:self];
            break;
    }
}

#pragma mark Alert Handling

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo {
    
    if (returnCode == NSAlertSecondButtonReturn) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://itunes.apple.com/gb/app/xcode/id497799835?mt=12"]];
    }
}

#pragma mark NSTextField Delegate

- (void)controlTextDidChange:(NSNotification *)aNotification  {
    if (([self.iTunesConnectUsernameField.stringValue length] > 0) && ([self.iTunesConnectPasswordField.stringValue length] > 0)) {
        [self setTransporterInteractionAvailability:YES];
        [[self statusTextField] setStringValue:@"Awaiting your command…"];
    }
    if ([self.iTunesConnectAppSKUField.stringValue length] > 0) {
        [[self downloadPackageFromiTunesConnectButton] setEnabled:YES];
    }
    
    if (([self.iTunesConnectUsernameField.stringValue length] == 0) && ([self.iTunesConnectPasswordField.stringValue length] == 0)) {
        [self setTransporterInteractionAvailability:NO];
        [[self statusTextField] setStringValue:@"Please enter your iTunes Connect credentials…"];
    }
    if ([self.iTunesConnectAppSKUField.stringValue length]== 0) {
        [[self downloadPackageFromiTunesConnectButton] setEnabled:NO];
    }
}

@end