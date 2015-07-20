#import "PlayerMachineViewController.h"
#import "Definition.h"
#import "Drawing.h"

#import "PGMidi/PGMidi.h"
#import "PGMidi/PGArc.h"
#import "PGMidi/iOSVersionDetection.h"

#import "MIDINote.h"
#import "NoteNumDict.h"
#import "Communicator.h"

#import "AdvancedPlayer.h"

/****** for getting ip address ******/
#import <ifaddrs.h>
#import <arpa/inet.h>

@interface PlayerMachineViewController () {
    /* Animation*/
    CGFloat mouseXReg[AnimateArrayLength];
    CGFloat mouseYReg[AnimateArrayLength];
    UInt16 tick[AnimateArrayLength];
    BOOL animate[AnimateArrayLength];
    
    /* notePosition */
    UInt16 notePos;
    UInt16 notePosReg[AnimateArrayLength];
    UInt8 velPos;
    
    /* the size parameter of the screen */
    CGFloat width;
    CGFloat height;
    
    /* UIBezierPath */
    UIBezierPath *path;
    CGPoint PPoint;
    
    /* Trace Stationary Point */
    CGFloat yReg[RegLength];
    BOOL RegValid;
    
    /* drawing elements */
    CGPoint lastPoint;
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat brush;
    CGFloat opacity;
    UInt16 length;
    BOOL mouseSwiped;
    
    /* other */
    BOOL longPressed;
    BOOL animateEnabled;
    UInt16 checkConnectedCounter;
}

@property (strong, nonatomic) IBOutlet UIImageView *mainImage;
@property (strong, nonatomic) IBOutlet UILabel *textLocation;
@property (strong, nonatomic) IBOutlet UIButton *IMAdvanced;
@property (strong, nonatomic) IBOutlet UIButton *QUIT;
@property (nonatomic, retain) NSTimer *draw;

/* The objects used during segue */
@property (nonatomic, retain) NSTimer *makeSureConnected;
@property (strong, nonatomic) IBOutlet UILabel *feedbackLabel;

/* Communication infrastructures */
@property (strong, nonatomic) Communicator *CMU;
@property (readonly) NoteNumDict *Dict;
@property (copy) NSString *ownIP;
@property (assign) UInt8 playerChannel;
@property (assign) UInt8 playerID;
@property (strong, nonatomic) NSMutableArray *MIDINoteArray;
@property (assign) BOOL playerEnabled;

/* Scoring and feedback */
- (void) scoringMeAndTeam:(NSNumber *)mixScore;
- (void) cueFeedback:(NSNumber *)cue;

/* Segue for advance player */
@property (strong, nonatomic) AdvancedPlayer *Adp;

@end

@implementation PlayerMachineViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self viewInit];
    [self infrastructureSetup];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:NO];
    self.feedbackLabel.alpha = 0;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:NO];
    // Initialize objects during segue
    _makeSureConnected = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkIfConnected) userInfo:nil repeats:YES];
    checkConnectedCounter = 0;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - setup routines
- (void)viewInit {
    red = 255.0/255.0;
    green = 255.0/255.0;
    blue = 255.0/255.0;
    brush = 1.0;
    opacity = 1.0;
    length = 0;
    notePos = 0;
    width = self.view.frame.size.width;
    height = self.view.frame.size.height;
    _draw = [NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(processingDraw) userInfo:nil repeats:YES];
    [self.mainImage setAlpha:opacity];
    
    [self clearAnimationArrays];
    [self clearStationCheckReg];
    
    self.IMAdvanced.alpha = 0;
    self.QUIT.alpha = 0;
    
    path = [UIBezierPath bezierPath];
    
    longPressed = false;
}

-(void)infrastructureSetup {
    if (_CMU == nil) {
        _CMU = [[Communicator alloc] init];
        [_CMU setAssignmentDelegate:self];
    }
    IF_IOS_HAS_COREMIDI(
        if (_CMU.midi == nil) {
            _CMU.midi = [[PGMidi alloc] init];
        }
    )
    if (_Dict == nil) {
        _Dict = [[NoteNumDict alloc] init];
    }
    _playerChannel = SteelGuitar;
    _playerID = 0xA; //an ID that doesn't exist
    _playerEnabled = false;
    _ownIP = [self getIPAddress];
    
    animateEnabled = true;
    
    if (_MIDINoteArray == nil) {
        _MIDINoteArray = [[NSMutableArray alloc] init];
        for (int i = 0; i < 22; i++) {
            MIDINote *M = [[MIDINote alloc] initWithNote:48 duration:1 channel:_playerChannel velocity:75 SysEx:0 Root:kMIDINoteOn];
            [_MIDINoteArray addObject:M];
        }
    }
    
}

#pragma mark - Assignment Handler (delegate of Communicator)
- (void)MIDIAssignment:(const MIDIPacket *)packet {
    NSLog(@"AssignmentDelegate Called");
    // handle sysEx messages which is an assignment from the master to players
    // The packet should contain more than 3 bytes of data, where the second byte is 0x7D the
    // manufacturer ID for educational use, the first byte is 0xF0, the last byte is 0xF7
    if (packet->length == 11) {
        NSLog(@"deals with normal assignment");
        for (int i = 2; i < 10; i++) {
            UInt8 AssignNum = packet->data[i];
            NSNumber *AssignNSNum = [NSNumber numberWithUnsignedChar:AssignNum];
            NSArray *noteNameArr = [_Dict.Dict allKeysForObject:AssignNSNum];
            NSString *noteName = [noteNameArr objectAtIndex:0];
            
            if (noteName) {
                NSLog(@"The noteName %@", noteName);
                NSNumber *noteNum = [_Dict.Dict objectForKey:noteName];
                UInt8 note = [noteNum unsignedShortValue];
                [[_MIDINoteArray objectAtIndex: 7- (i- 2)] setNote:note];
                [[_MIDINoteArray objectAtIndex: 14 - (i- 2)] setNote:note - 12];
                [[_MIDINoteArray objectAtIndex: 21 - (i- 2)] setNote:note - 24];
                [[_MIDINoteArray objectAtIndex:7-(i-2)] setChannel:_playerChannel];
                [[_MIDINoteArray objectAtIndex:14-(i-2)] setChannel:_playerChannel];
                [[_MIDINoteArray objectAtIndex:21-(i-2)] setChannel:_playerChannel];
            }
        }
        _playerEnabled = true;
        
    } else if (packet->length == 13) {
        UInt8 add1 = (packet->data[2]) << 4 | packet->data[3];
        UInt8 add2 = (packet->data[4]) << 4 | packet->data[5];
        UInt8 add3 = (packet->data[6]) << 4 | packet->data[7];
        UInt8 add4 = (packet->data[8]) << 4 | packet->data[9];
        
        NSArray *Arr;
        Arr = [_ownIP componentsSeparatedByString:@"."];
        int ad1 = [Arr[0] intValue];
        int ad2 = [Arr[1] intValue];
        int ad3 = [Arr[2] intValue];
        int ad4 = [Arr[3] intValue];
        // Check if the IP address match, if true, get the channel number inside the packet
        if (add1 == (UInt8)ad1 && add2 == (UInt8)ad2 && add3 == (UInt8)ad3 && add4 == (UInt8)ad4) {
            UInt8 Root = packet->data[10];
            if (Root < 10) {
                NSLog(@"deal with channel and ID mapping broadcast");
                _playerChannel = Root;
                _playerID = packet->data[11];
                NSLog(@"Player Channel is: %d", _playerChannel);
                NSLog(@"Player ID is: %d", _playerID);
                for (MIDINote *M in _MIDINoteArray) {
                    [M setChannel:_playerChannel];
                    [M setID:_playerID];
                }
            } else if (Root < 60 && Root > 10) {
                NSLog(@"deal with cue feedback");
                NSNumber *cue = [NSNumber numberWithUnsignedChar:(Root - 50)];
                [self performSelectorInBackground:@selector(cueFeedback:) withObject:cue];
            } else {
                NSLog(@"deal with score feedback");
                UInt8 myScore = Root;
                UInt8 overallScore = packet->data[11];
                NSLog(@"player score = %d", myScore);
                NSLog(@"overall score = %d", overallScore);
                UInt16 score = overallScore << 8 | myScore;
                NSNumber *mixScore = [NSNumber numberWithUnsignedShort:score];
                [self performSelectorInBackground:@selector(scoringMeAndTeam:) withObject:mixScore];
            }
        }
    } else if (packet->length == 4) {
        NSLog(@"deals with stop jamming");
        _playerEnabled = false;
    }
}

// The following code is adapted from the stackflow Q&A website:
// http://stackoverflow.com/questions/7072989/iphone-ipad-how-to-get-my-ip-address-programmatically
- (NSString *)getIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
}

#pragma mark - Make Sure Process After Segue
- (void)checkIfConnected {
    // Should wait for some time because there are fake temperary connections
    if (checkConnectedCounter++ > 2) {
        checkConnectedCounter = 0;
        if (*_masterConnected && !_playerEnabled) {
            animateEnabled = true;
            [UIView animateWithDuration:1 animations:^{self.feedbackLabel.alpha = 1;}];
            [UIView animateWithDuration:1 delay:1 options:UIViewAnimationOptionTransitionCurlUp
                             animations:^{self.feedbackLabel.alpha = 0;} completion:NO];
            _feedbackLabel.text = @"waiting for Master...";
        } else if (_playerEnabled) {
            if (animateEnabled) {
                _feedbackLabel.text = @"tap or draw to Jam...";
                [UIView animateWithDuration:1 animations:^{self.feedbackLabel.alpha = 1;}];
                [UIView animateWithDuration:1 delay:1 options:UIViewAnimationOptionTransitionCurlUp
                                 animations:^{self.feedbackLabel.alpha = 0;} completion:NO];
            }
            animateEnabled = false;
        } else {
#ifndef VIEWTEST
            animateEnabled = true;
            [self dismissViewControllerAnimated:YES completion:nil];
#endif
        }
    }
}

#pragma mark - Scoring and cue feedback

- (void) scoringMeAndTeam:(NSNumber *)mixScore {
    UInt16 mix = [mixScore unsignedShortValue];
    UInt8 myScore = mix & 0x00FF;
    UInt8 overallScore = (mix & 0xFF00) >> 8;
    NSLog(@"myScore = %d", myScore);
    NSLog(@"overallScore = %d", overallScore);
    
    NSString *Score = [NSString stringWithFormat:@"Me/Team: %d/%d", myScore, overallScore];
    [self feebackAnimatewithString: Score];
    
    // Send the score to the advanced player too
    if (_Adp) {
        [_Adp feebackAnimatewithString:Score];
    }
}

- (void) cueFeedback:(NSNumber *)cue {
    UInt8 Cue = [cue unsignedCharValue];
    NSString *CueString;
    switch (Cue) {
        case 0:
            CueString = @"Good";
            break;
        case 1:
            CueString = @"Slow";
            break;
        case 2:
            CueString = @"Fast";
            break;
        case 3:
            CueString = @"Solo";
            break;
        case 4:
            CueString = @"High";
            break;
        case 5:
            CueString = @"Ready";
            break;
        case 6:
            CueString = @"Strong";
            break;
        case 7:
            CueString = @"Calm";
            break;
            
        default:
            break;
    }
    [self feebackAnimatewithString:CueString];
    
    // Send to cue to the advanced player too
    if (_Adp) {
        [_Adp feebackAnimatewithString:CueString];
    }
}

- (void) feebackAnimatewithString:(NSString *)feedback {
    _feedbackLabel.alpha = 0;
    _feedbackLabel.text = feedback;
    [UIView animateWithDuration:1 animations:^{_feedbackLabel.alpha = 1;}];
    [UIView animateWithDuration:1 delay:1 options:UIViewAnimationOptionTransitionCurlUp animations:^{_feedbackLabel.alpha = 0;} completion:NO];
}

#pragma mark - Drawing

static CGPoint midPoint(CGPoint p0, CGPoint p1) {
    return CGPointMake((p0.x + p1.x)/2, (p0.y + p1.y)/2);
}

// mousePressed
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (longPressed) {
        longPressed = false;
        [UIView animateWithDuration:1 animations:^{self.IMAdvanced.alpha = 0.0;}];
        [UIView animateWithDuration:1 animations:^{self.QUIT.alpha = 0.0;}];
    }
    mouseSwiped = NO;
    UITouch *touch = [touches anyObject];
    lastPoint = [touch locationInView:self.view];
    
    path = [UIBezierPath bezierPath];
    [path moveToPoint:lastPoint];
    
    // Play the note, which is determined by the y position and how many notes are within the screen size
    notePos = lastPoint.y * noteSize / height;
    velPos = lastPoint.x *127 / width;
    [self playNoteinPos:notePos withVelocity:velPos andType:kMIDINoteOn];
    [self tracePressedwithPos:lastPoint.x and:lastPoint.y notePos:notePos];
}

// mouseDragged
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    DSLog(@"length = %d", length);
    if (length ++ == 10) {
        length = 0;
        path = [UIBezierPath bezierPath];
        [path moveToPoint:lastPoint];
    }
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.view];
    mouseSwiped = YES;
    
    CGPoint middlePoint = midPoint(lastPoint, currentPoint);
    [path addQuadCurveToPoint:middlePoint controlPoint:lastPoint];
    
    UIGraphicsBeginImageContext(self.view.frame.size);
    [self.mainImage.image drawInRect:CGRectMake(0, 0, self.mainImage.frame.size.width, self.mainImage.frame.size.height)];
    [[UIColor whiteColor] setStroke];
    [path setLineWidth:brush];
    [path stroke];
    CGContextAddPath(UIGraphicsGetCurrentContext(), path.CGPath);
    self.mainImage.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    lastPoint = currentPoint;
    
    // Trace Stationary Point
    [self traceStationarywithPos:currentPoint.y];
    if (RegValid) {
        if ([self isStationary]) {
            RegValid = NO;
            if (_playerChannel != Ensemble) {
                notePos = lastPoint.y * noteSize / height;
                velPos = lastPoint.x * 127 / width;
                [self playNoteinPos:notePos withVelocity:velPos andType:kMIDINoteOn];
            }
            [self tracePressedwithPos:currentPoint.x and:currentPoint.y notePos:notePos];
        }
    }
}

// mouseReleased
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_playerChannel == Ensemble) {
        [self playNoteinPos:notePos withVelocity:0 andType:kMIDINoteOff];
    }
}

#pragma mark - Play Note
- (void)playNoteinPos:(UInt16)Pos withVelocity:(UInt8)Vel andType:(UInt8)Type{
    if (_playerEnabled) {
        MIDINote *M = [_MIDINoteArray objectAtIndex:Pos];
        [M setVelocity:Vel];
        [_CMU sendMidiData:M];
    }
}

#pragma mark - Timer Triggered Function
/***** This process is called once per 0.03 second to simulate the "processing"'s style http://www.processing.org of drawing ability ******/
- (void)processingDraw {
    [self doAnimation];
}

#pragma mark - TraceStationaryPoint
- (BOOL) isStationary{
    //Check the non-stationary condition, if true return false, else, return true
    BOOL ret = true;
    for (int i = 1; i < RegLength; i++) {
        if (yReg[i-1] >= yReg[i]) {
            ret &= true;
        } else {
            ret &= false;
            break;
        }
    }
    // if non-station, return false
    if (ret)
        return false;
    
    ret = true;
    for (int i = 1; i < RegLength; i++) {
        if (yReg[i-1] <= yReg[i]) {
            ret &= true;
        } else {
            ret &= false;
            break;
        }
    }
    // if non-station, return false
    if (ret)
        return false;
    
    // else return true
    return true;
}

- (void) clearStationCheckReg {
    for (int i = 0 ; i < RegLength; i++) {
        yReg[i] = 0;
    }
}

- (void) traceStationarywithPos:(CGFloat)y {
    for (int i = 1; i < RegLength; i++) {
        yReg[i-1] = yReg[i];
    }
    yReg[RegLength - 1] = y;
    if (yReg[0] > 0)
        RegValid = YES;
    else
        RegValid = NO;
}

#pragma mark - Animation
// This is a result of my processing simulation
- (void) doAnimation {
    // do some fading effect
    [self fading];
    
    // do water effect
    for (int i = 0; i < AnimateArrayLength; i++) {
        if (animate[i]) {
            tick[i]++;
            if (tick[i] > 45) {
                tick[i] = 0;
                animate[i] = false;
            }
            if (tick[i] > 30 && tick[i] <=45) {
                [Drawing drawCircleWithCenter:CGPointMake(mouseXReg[i], mouseYReg[i]) Radius:2*(notePosReg[i]+2) onImage:self.mainImage withbrush:brush Red:red Green:green Blue:blue Alpha:opacity Size:self.view.frame.size];
            }
            if (tick[i] > 15 && tick[i] <= 30) {
                [Drawing drawCircleWithCenter:CGPointMake(mouseXReg[i], mouseYReg[i]) Radius:1.5*(notePosReg[i]+2) onImage:self.mainImage withbrush:brush Red:red Green:green Blue:blue Alpha:opacity Size:self.view.frame.size];
            }
            if (tick[i] > 1 && tick[i] <= 15) {
                [Drawing drawCircleWithCenter:CGPointMake(mouseXReg[i], mouseYReg[i]) Radius:(notePosReg[i]+2) onImage:self.mainImage withbrush:brush Red:red Green:green Blue:blue Alpha:opacity Size:self.view.frame.size];
            }
        }
    }
}

- (void) fading {
    UIGraphicsBeginImageContext(self.view.frame.size);
    [self.mainImage.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) blendMode:kCGBlendModeNormal alpha:1.0];
    CGContextSetRGBFillColor(UIGraphicsGetCurrentContext(), 0, 0, 0, 0.1);
    CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height));
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    CGContextFlush(UIGraphicsGetCurrentContext());
    self.mainImage.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

- (void) tracePressedwithPos:(CGFloat)x and:(CGFloat)y notePos:(UInt16)Pos {
    for (int i = 1; i < AnimateArrayLength; i++) {
        mouseXReg[i-1] = mouseXReg[i];
        mouseYReg[i-1] = mouseYReg[i];
        tick[i-1] = tick[i];
        animate[i-1] = animate[i];
        notePosReg[i - 1] = notePosReg[i];
    }
    mouseXReg[AnimateArrayLength - 1] = x;
    mouseYReg[AnimateArrayLength - 1] = y;
    tick[AnimateArrayLength - 1] = 0;
    animate[AnimateArrayLength - 1] = YES;
    notePosReg[AnimateArrayLength - 1] = Pos;
    
    [self clearStationCheckReg];
}

- (void) clearAnimationArrays {
    for (int i = 0; i < AnimateArrayLength; i++) {
        mouseXReg[i] = 0;
        mouseYReg[i] = 0;
        tick[i] = 0;
        animate[i] = NO;
        notePosReg[i] = 0;
    }
}

#pragma mark - Segue
/****** pass any essential variables to advanced player ******/
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    _Adp = (AdvancedPlayer *)segue.destinationViewController;
    _Adp.CMU = _CMU;
    _Adp.playerChannel = &_playerChannel;
    _Adp.playerID = &_playerID;
    _Adp.playerEnabled = &_playerEnabled;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}

- (IBAction)LongPressed:(id)sender {
    if (_playerChannel != Ensemble) {
        DSLog(@"LongPressed");
        [UIView animateWithDuration:1 animations:^{self.IMAdvanced.alpha = 1;}];
        [UIView animateWithDuration:1 animations:^{self.QUIT.alpha = 1;}];
        longPressed = true;
    }
}

- (IBAction)QUIT:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
    [UIView animateWithDuration:1 animations:^{self.IMAdvanced.alpha = 0;}];
    [UIView animateWithDuration:1 animations:^{self.QUIT.alpha = 0;}];
}

- (IBAction)GotoAdvanced:(id)sender {
    [UIView animateWithDuration:1 animations:^{self.IMAdvanced.alpha = 0;}];
    [UIView animateWithDuration:1 animations:^{self.QUIT.alpha = 0;}];
}


@end
