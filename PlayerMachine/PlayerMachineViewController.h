#import <UIKit/UIKit.h>
#import "Definition.h"
#import "Communicator.h"

@interface PlayerMachineViewController : UIViewController <UIGestureRecognizerDelegate, MIDIAssignmentHandle>

// The objects used during segue
@property BOOL *masterConnected;

@end
