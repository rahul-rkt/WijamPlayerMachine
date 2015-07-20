#import <UIKit/UIKit.h>

@interface Drawing : UIViewController

+ (void) drawCircleWithCenter:(CGPoint)center Radius:(CGFloat)radius onImage:(UIImageView *)Img withbrush:(UInt16)brush
                          Red:(CGFloat)red Green:(CGFloat)green Blue:(CGFloat)blue Alpha:(CGFloat)opacity Size:(CGSize)size;

+ (void) drawLineWithPreviousPoint:(CGPoint)PP CurrentPoint:(CGPoint)CP onImage:(UIImageView *)Img withbrush:(UInt16)brush
                               Red:(CGFloat)red Green:(CGFloat)green Blue:(CGFloat)blue Alpha:(CGFloat)opacity Size:(CGSize)size;

@end

