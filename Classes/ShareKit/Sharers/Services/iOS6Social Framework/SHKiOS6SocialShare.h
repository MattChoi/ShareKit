//
//  SHKiOS6ScocialShare.h
//  ShareKit
//
//  Created by Matt Choi on 31/8/12.
//
//

#import "SHKSharer.h"

typedef enum{
    SHKSLServiceTypeNone        =   0,
    SHKSLServiceTypeFacebook    =   1,
    SHKSLServiceTypeSinaWeibo   =   2,
    SHKSLServiceTypeTwitter     =   3,
} SHKSLServiceType;

@interface SHKiOS6SocialShare : SHKSharer
+ (void)SLServiceType:(SHKSLServiceType)type;
@end
