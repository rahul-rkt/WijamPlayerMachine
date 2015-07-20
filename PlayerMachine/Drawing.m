#import "Drawing.h"

@interface Drawing ()

@end

@implementation Drawing

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Drawing Implementation

#pragma mark - Drawing

+ (void) drawCircleWithCenter:(CGPoint)center Radius:(CGFloat)radius onImage:(UIImageView *)Img withbrush:(UInt16)brush
                          Red:(CGFloat)red Green:(CGFloat)green Blue:(CGFloat)blue Alpha:(CGFloat)opacity  Size:(CGSize)size{
    UIGraphicsBeginImageContext(size);
    [Img.image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), brush);
    CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), red, green, blue, opacity);
    //Try drawing a circle
    CGContextAddEllipseInRect(UIGraphicsGetCurrentContext(), CGRectMake(center.x-radius, center.y-radius, 2*radius, 2*radius));
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    CGContextFlush(UIGraphicsGetCurrentContext());
    Img.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

+ (void) drawLineWithPreviousPoint:(CGPoint)PP CurrentPoint:(CGPoint)CP onImage:(UIImageView *)Img withbrush:(UInt16)brush
                               Red:(CGFloat)red Green:(CGFloat)green Blue:(CGFloat)blue Alpha:(CGFloat)opacity Size:(CGSize)size{
    UIGraphicsBeginImageContext(size);
    [Img.image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), PP.x, PP.y);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), CP.x, CP.y);
    CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), brush);
    CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), red, green, blue, opacity);
    CGContextSetBlendMode(UIGraphicsGetCurrentContext(), kCGBlendModeNormal);
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    Img.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

@end
