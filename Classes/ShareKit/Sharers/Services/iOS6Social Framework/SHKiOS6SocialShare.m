//
//  SHKiOS6ScocialShare.m
//  ShareKit
//
//  Created by Matt Choi on 31/8/12.
//
//

#import "SHKiOS6SocialShare.h"
#import "SHK.h"
#import <Social/Social.h>

static SHKSLServiceType socicalType;

@interface SHKiOS6SocialShare ()

@property (retain) UIViewController *currentTopViewController;

- (void)callUI:(NSNotification *)notif;
- (void)presentUI;

@end

@implementation SHKiOS6SocialShare

@synthesize currentTopViewController;

- (void)dealloc {
    
    [currentTopViewController release];
    [super dealloc];
}

+ (void)SLServiceType:(SHKSLServiceType)type
{
    socicalType = type;
}

+ (NSString *)sharerTitle
{
    switch (socicalType) {
        case SHKSLServiceTypeFacebook:
           return @"Facebook"; 
            break;
        case SHKSLServiceTypeSinaWeibo:
            return @"Weibo";
            break;
        case SHKSLServiceTypeTwitter:
            return @"Twitter";
            break;
        case SHKSLServiceTypeNone:
            return @"";
            break;
            
    }
    
    return @"";
}

+ (NSString *)sharerId
{
    switch (socicalType) {
        case SHKSLServiceTypeFacebook:
            return @"SHKFacebook";
            break;
        case SHKSLServiceTypeSinaWeibo:
            return @"SHKWeibo";
            break;
        case SHKSLServiceTypeTwitter:
            return @"SHKTwitter";
            break;
        case SHKSLServiceTypeNone:
            return @"";
            break;
            
    }
	return @"";
}

- (void)share {
    
    if ([[SHK currentHelper] currentView]) { //user is sharing from SHKShareMenu
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(callUI:)
                                                     name:SHKHideCurrentViewFinishedNotification
                                                   object:nil];
        [self retain];  //must retain, so that it is still around for SHKShareMenu hide callback. Menu hides asynchronously when sharer is chosen.
        
    } else {        
        [self presentUI];
    }
}

#pragma mark -

- (void)callUI:(NSNotification *)notif {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SHKHideCurrentViewFinishedNotification object:nil];
    [self presentUI];
    [self release]; //see share
}

- (void)presentUI {
    
    if ([self.item shareType] == SHKShareTypeUserInfo) {
        SHKLog(@"User info not possible to download on iOS+6. You can get Twitter enabled user info from Accounts framework");
        return;
    }
    
    SLComposeViewController *iOS6Social = nil;
    
    switch (socicalType) {
        case SHKSLServiceTypeFacebook:
        {
            iOS6Social = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];

        }
            break;
        case SHKSLServiceTypeSinaWeibo:
        {
            iOS6Social = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeSinaWeibo];

        }
            break;
        case SHKSLServiceTypeTwitter:
        {
            iOS6Social = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];  
        }
            break;
            
        case SHKSLServiceTypeNone:
            return;
            break;
            
    }
  
    
    [iOS6Social addImage:self.item.image];
    [iOS6Social addURL:self.item.URL];
    
    if ([self.item.text length]>0 ) {
        [iOS6Social setInitialText:[item.text length]>140 ? [item.text substringToIndex:140] : item.text];
    } else {
        [iOS6Social setInitialText:[item.title length]>140 ? [item.title substringToIndex:140] : item.title];
    }
    
    iOS6Social.completionHandler = ^(SLComposeViewControllerResult result)
    {
        [self.currentTopViewController dismissViewControllerAnimated:YES completion:^{
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [[NSNotificationCenter defaultCenter] postNotificationName:SHKHideCurrentViewFinishedNotification object:nil];
            }];
        }];
        
        switch (result) {
                
            case SLComposeViewControllerResultDone:
                [self sendDidFinish];
                break;
                
            case SLComposeViewControllerResultCancelled:
                [self sendDidCancel];
                
            default:
                break;
        }
    };
    
    self.currentTopViewController = [[SHK currentHelper] rootViewForCustomUIDisplay];
    [self.currentTopViewController presentViewController:iOS6Social animated:YES completion:nil];
}

@end
