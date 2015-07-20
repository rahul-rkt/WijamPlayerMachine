#import <UIKit/UIKit.h>
#import "NoteNumDict.h"
#import "Communicator.h"

@interface AdvancedPlayer : UIViewController <UIGestureRecognizerDelegate>

@property (strong, nonatomic) Communicator *CMU;
@property (assign) UInt8 *playerChannel;
@property (assign) UInt8 *playerID;
@property (assign) BOOL *playerEnabled;

- (void) feebackAnimatewithString:(NSString *)feedback;

@end
