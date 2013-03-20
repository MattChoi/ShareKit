//
//  SHKFacebook.m
//  ShareKit
//
//  Created by Nathan Weiner on 6/18/10.

//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//

#import "SHKFacebook.h"
#import "SHKConfiguration.h"
#import "NSMutableDictionary+NSNullsToEmptyStrings.h"
#import "SHKiOS6SocialShare.h"

static NSString *const kSHKStoredItemKey=@"kSHKStoredItem";
static NSString *const kSHKFacebookAccessTokenKey=@"kSHKFacebookAccessToken";
static NSString *const kSHKFacebookExpiryDateKey=@"kSHKFacebookExpiryDate";
static NSString *const kSHKFacebookUserInfo =@"kSHKFacebookUserInfo";

@interface SHKFacebook()

//+ (Facebook*)facebook;
+ (void)flushAccessToken;
+ (NSString *)storedImagePath:(UIImage*)image;
+ (UIImage*)storedImage:(NSString*)imagePath;
- (void)showFacebookForm;
- (void)saveFBAccessToken:(NSString *)accessToken expiring:(NSDate *)expiryDate;

@end

@implementation SHKFacebook

- (void)dealloc
{
//  if ([SHKFacebook facebook].sessionDelegate == self)
//    [SHKFacebook facebook].sessionDelegate = nil;
	[super dealloc];
}

+ (void)flushAccessToken 
{

    [[FBSession activeSession] closeAndClearTokenInformation];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults removeObjectForKey:kSHKFacebookAccessTokenKey];
  [defaults removeObjectForKey:kSHKFacebookExpiryDateKey];
  [defaults removeObjectForKey:kSHKFacebookUserInfo];
  [defaults synchronize];
}

+ (NSString *)storedImagePath:(UIImage*)image
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *paths = NSSearchPathForDirectoriesInDomains( NSCachesDirectory, NSUserDomainMask, YES);
	NSString *cache = [paths objectAtIndex:0];
	NSString *imagePath = [cache stringByAppendingPathComponent:@"SHKImage"];
	
	// Check if the path exists, otherwise create it
	if (![fileManager fileExistsAtPath:imagePath]) 
		[fileManager createDirectoryAtPath:imagePath withIntermediateDirectories:YES attributes:nil error:nil];
	
  NSString *uid = [NSString stringWithFormat:@"img-%f-%i", [[NSDate date] timeIntervalSince1970], arc4random()];
  // store image in cache
  NSData *imageData = UIImagePNGRepresentation(image);
  imagePath = [imagePath stringByAppendingPathComponent:uid];
  [imageData writeToFile:imagePath atomically:YES];
  
	return imagePath;
}

+ (UIImage*)storedImage:(NSString*)imagePath {
  NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
  UIImage *image = nil;
  if (imageData) {
    image = [UIImage imageWithData:imageData];
  }
  // Unlink the stored file:
  [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
  return image;
}

+ (BOOL)handleOpenURL:(NSURL*)url 
{
    return [[FBSession activeSession] handleOpenURL:url];
}

#pragma mark -
#pragma mark Configuration : Service Defination

+ (NSString *)sharerTitle
{
	return @"Facebook";
}

+ (BOOL)canShareURL
{
	return YES;
}

+ (BOOL)canShareText
{
	return YES;
}

+ (BOOL)canShareImage
{
	return YES;
}

+ (BOOL)canShareOffline
{
	return NO; // TODO - would love to make this work
}

+ (BOOL)canGetUserInfo
{
    return YES;
}

#pragma mark -
#pragma mark Configuration : Dynamic Enable

- (BOOL)shouldAutoShare
{
	return NO;
}



- (void)share {
	
    if ([self iOS6ScoialShareFrameworkAvailable]) {
        [SHKiOS6SocialShare SLServiceType:SHKSLServiceTypeFacebook];
        SHKSharer *sharer =[SHKiOS6SocialShare shareItem:self.item];
        sharer.quiet = self.quiet;
        sharer.shareDelegate = self.shareDelegate;
		[SHKFacebook logout];//to clean credentials - we will not need them anymore
		return;        
    }
    
    [super share];
}

- (BOOL)iOS6ScoialShareFrameworkAvailable {
    
    if (NSClassFromString(@"SLComposeViewController")) {
		return YES;
	}
	
	return NO;
}


#pragma mark -
#pragma mark Authentication

- (BOOL)isAuthorized
{	  
    // See if we have a valid token for the current state.
    if (FBSession.activeSession.state == FBSessionStateOpen) {
        // To-do, show logged in view
        return YES;
    } else {
        // No, display the login page.
        [self promptAuthorization];
    }
}

- (void)promptAuthorization
{
	NSMutableDictionary *itemRep = [NSMutableDictionary dictionaryWithDictionary:[self.item dictionaryRepresentation]];
	if (item.image)
	{
		[itemRep setObject:[SHKFacebook storedImagePath:item.image] forKey:@"imagePath"];
	}
	[[NSUserDefaults standardUserDefaults] setObject:itemRep forKey:kSHKStoredItemKey];
    
    [FBSession openActiveSessionWithReadPermissions:nil
                                       allowLoginUI:YES
                                  completionHandler:
     ^(FBSession *session,
       FBSessionState state, NSError *error) {
         [self sessionStateChanged:session state:state error:error];
     }];

}

+ (void)logout
{
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSHKStoredItemKey];
  [self flushAccessToken];
}

#pragma mark -
#pragma mark Share API Methods

- (BOOL)send
{			
 	if (![self validateItem])
		return NO;
    FBRequestConnection *connection = [[[FBRequestConnection alloc] init] autorelease];

        if (item.shareType == SHKShareTypeURL && item.URL)
	{
		NSString *url = [item.URL absoluteString];
        NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       self.item.facebookURLShareDescription?self.item.facebookURLShareDescription:@"",@"description",
                                       self.item.facebookURLSharePictureURI?self.item.facebookURLSharePictureURI:@"",@"picture",
                                       url?url:@"", @"link",
                                       item.title, @"message",
                                       SHKCONFIG(appName),@"name",
                                       nil];

        // Invoke the dialog
        [FBWebDialogs presentFeedDialogModallyWithSession:nil
                                               parameters:params
                                                  handler:
         ^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
             if (error) {
                 // Case A: Error launching the dialog or publishing story.
                 NSLog(@"Error publishing story.");
             } else {
                 if (result == FBWebDialogResultDialogNotCompleted) {
                     // Case B: User clicked the "x" icon
                     NSLog(@"User canceled story publishing.");
                 } else {
                     // Case C: Dialog shown and the user clicks Cancel or Share
                     NSDictionary *urlParams = nil;
                     if (![urlParams valueForKey:@"post_id"]) {
                         // User clicked the Cancel button
                         NSLog(@"User canceled story publishing.");
                     } else {
                         // User clicked the Share button
                         NSString *postID = [urlParams valueForKey:@"post_id"];
                         NSLog(@"Posted story, id: %@", postID);
                     }
                 }
             }
         }];
        
        return YES;
        
	}
	else if (item.shareType == SHKShareTypeText && item.text)
	{

        // First request posts a status update
        NSDictionary *request1Params = [[NSDictionary alloc]
                                        initWithObjectsAndKeys:
                                        item.text, @"message",
                                        nil];
        FBRequest *request1 =
        [FBRequest requestWithGraphPath:@"me/feed"
                             parameters:request1Params
                             HTTPMethod:@"POST"];
        [connection addRequest:request1
             completionHandler:
         ^(FBRequestConnection *connection, id result, NSError *error) {
             if (!error) {
             }else{
                 // error_code=190: user changed password or revoked access to the application,
                 // so spin the user back over to authentication :
                 if (error.code == 190)
                 {
                     [SHKFacebook flushAccessToken];
                     [self authorize];
                 }
             }
             [self sendDidFinish];
         }
                batchEntryName:@"status-post"
         ];
	}
	else if (item.shareType == SHKShareTypeImage && item.image)
	{
        FBRequest *request1 = [FBRequest
                               requestForUploadPhoto:self.item.image];
        [connection addRequest:request1
             completionHandler:
         ^(FBRequestConnection *connection, id result, NSError *error) {
             if (!error) {
             }else{
                 // error_code=190: user changed password or revoked access to the application,
                 // so spin the user back over to authentication :
                 if (error.code == 190)
                 {
                     [SHKFacebook flushAccessToken];
                     [self authorize];
                 }
             }
             [self sendDidFinish];
         }
                batchEntryName:nil
         ];
	}
    else if (item.shareType == SHKShareTypeUserInfo)
    {
        [self setQuiet:YES];
        [[[FBRequest requestForMe] startWithCompletionHandler:
         ^(FBRequestConnection *connection,
           NSDictionary <FBGraphUser> *user,
           NSError *error) {
             if (!error) {

             }else{
                 // error_code=190: user changed password or revoked access to the application,
                 // so spin the user back over to authentication :
                 if (error.code == 190)
                 {
                     [SHKFacebook flushAccessToken];
                     [self authorize];
                 }
             }
             [self sendDidFinish];
         }] autorelease];
    }
	else
		// There is nothing to send
		return NO;

    [connection start];
    [self sendDidStart];
	return YES;
}

#pragma mark -
#pragma mark FBDialogDelegate methods
//
//- (void)dialogDidComplete:(FBDialog *)dialog
//{
//  [self sendDidFinish];  
//    [self release]; //see [self send]
//}
//
//- (void)dialogDidNotComplete:(FBDialog *)dialog
//{
//  [self sendDidCancel];
//    [self release]; //see [self send]
//}
//
//- (void)dialogCompleteWithUrl:(NSURL *)url 
//{
//  //if user presses cancel within webview FBDialogue, return string is without any other parameter, see issue #83. We should not show "Saved!".
//  if ([[url absoluteString] isEqualToString:@"fbconnect://success"]) { 
//      [self setQuiet:YES];
//  }
//  // error_code=190: user changed password or revoked access to the application,
//  // so spin the user back over to authentication :
//  NSRange errorRange = [[url absoluteString] rangeOfString:@"error_code=190"];
//  if (errorRange.location != NSNotFound) 
//  {
//    [SHKFacebook flushAccessToken];
//    [self authorize];
//  }
//}
//
//- (void)dialogDidCancel:(FBDialog*)dialog
//{
//  [self sendDidCancel];
//    [self release]; //see [self send]
//}
//
//- (void)dialog:(FBDialog *)dialog didFailWithError:(NSError *)error 
//{
//  if (error.code != NSURLErrorCancelled)
//    [self sendDidFailWithError:error];
//    [self release]; //see [self send]
//}
//
//- (BOOL)dialog:(FBDialog*)dialog shouldOpenURLInExternalBrowser:(NSURL*)url
//{
//    [self release]; //see [self promptAuthorization]. If callback happens, self will retain again.
//	return YES;
//    
//}

#pragma mark - FBSessionDelegate methods

- (void)fbDidLogin 
{
	NSString *accessToken = [[SHKFacebook facebook] accessToken];
	NSDate *expiryDate = [[SHKFacebook facebook] expirationDate];
    [self saveFBAccessToken:accessToken expiring:expiryDate];
	
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *storedItem = [defaults objectForKey:kSHKStoredItemKey];
	if (storedItem)
	{
		self.item = [SHKItem itemFromDictionary:storedItem];
		NSString *imagePath = [storedItem objectForKey:@"imagePath"];
		if (imagePath) {
			self.item.image = [SHKFacebook storedImage:imagePath];
		}
		[defaults removeObjectForKey:kSHKStoredItemKey];
	}
	[defaults synchronize];
    [self authDidFinish:true];
	
    if (self.item)        
        [self tryPendingAction];
	
    [self release]; //see [self promptAuthorization]
}

- (void)fbDidNotLogin:(BOOL)cancelled {
    
    if (!cancelled) {
        [[[[UIAlertView alloc] initWithTitle:SHKLocalizedString(@"Authorize Error")
									 message:SHKLocalizedString(@"There was an error while authorizing")
									delegate:nil
						   cancelButtonTitle:SHKLocalizedString(@"Close")
						   otherButtonTitles:nil] autorelease] show];
    }
    
    [self authDidFinish:NO]; 
    [self release]; //see [self promptAuthorization]
}

- (void)fbDidExtendToken:(NSString*)accessToken
               expiresAt:(NSDate*)expiresAt {
    
    [self saveFBAccessToken:accessToken expiring:expiresAt];
    
}

- (void)fbDidLogout {
 
    //we do nothing now, as we called [self flushAccessToken] during + (void)logout
}

- (void)fbSessionInvalidated {
    
}

#pragma mark -

- (void)saveFBAccessToken:(NSString *)accessToken expiring:(NSDate *)expiryDate {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:accessToken forKey:kSHKFacebookAccessTokenKey];
	[defaults setObject:expiryDate forKey:kSHKFacebookExpiryDateKey];
    [defaults synchronize];
}


#pragma mark FBSession

- (void)sessionStateChanged:(FBSession *)session
                      state:(FBSessionState) state
                      error:(NSError *)error
{
    
    switch (state) {
        case FBSessionStateOpen: {
            [[FBRequest requestForMe] startWithCompletionHandler:
             ^(FBRequestConnection *connection,
               NSDictionary <FBGraphUser> *user,
               NSError *error) {
    
                 
             }];
            
        }
            break;
        case FBSessionStateClosed:
        case FBSessionStateClosedLoginFailed:
            break;
        default:
            break;
    }
    
    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Error"
                                  message:error.localizedDescription
                                  delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];
    }
}

#pragma mark - FBRequestDelegate methods
//
//- (void)requestLoading:(FBRequest *)request
//{
//  [self sendDidStart];
//}
//
//- (void)request:(FBRequest *)fbRequest didLoad:(id)result
//{   
//    if ([fbRequest.url hasSuffix:@"/me"] && [result objectForKey:@"id"]) {
//        [result convertNSNullsToEmptyStrings];
//        [[NSUserDefaults standardUserDefaults] setObject:result forKey:kSHKFacebookUserInfo];
//    }     
//
//    [self sendDidFinish];
//    [self release]; //see [self send]
//}
//
//- (void)request:(FBRequest*)aRequest didFailWithError:(NSError*)error 
//{
//    //if user revoked app permissions
//    NSNumber *fbErrorCode = [[error.userInfo valueForKey:@"error"] valueForKey:@"code"];
//    if (error.domain == @"facebookErrDomain" && [fbErrorCode intValue] == 190) {
//        [self shouldReloginWithPendingAction:SHKPendingSend];
//    } else {
//        [self sendDidFailWithError:error];
//    }
//    
//    [self release]; //see [self send]
//}


#pragma mark - UI Implementation

- (void)show
{
    if (item.shareType == SHKShareTypeText || item.shareType == SHKShareTypeImage)        
    {
        [self showFacebookForm];
    }
 	else
    {
        [self tryToSend];
    }
}

- (void)showFacebookForm
{
 	SHKCustomFormControllerLargeTextField *rootView = [[SHKCustomFormControllerLargeTextField alloc] initWithNibName:nil bundle:nil delegate:self];  
 	
    switch (self.item.shareType) {
        case SHKShareTypeText:
            rootView.text = item.text;
            break;
        case SHKShareTypeImage:
            rootView.image = item.image;
            rootView.text = item.text;
        default:
            break;
    }    
    
    self.navigationBar.tintColor = SHKCONFIG_WITH_ARGUMENT(barTintForView:,self);
 	[self pushViewController:rootView animated:NO];
    [rootView release];
    
    [[SHK currentHelper] showViewController:self];  
}

- (void)sendForm:(SHKCustomFormControllerLargeTextField *)form
{  
 	switch (self.item.shareType) {
        case SHKShareTypeText:
            self.item.text = form.textView.text;
            break;
        case SHKShareTypeImage:
            self.item.text = form.textView.text;
        default:
            break;
    }    
    
 	[self tryToSend];
}  

@end
