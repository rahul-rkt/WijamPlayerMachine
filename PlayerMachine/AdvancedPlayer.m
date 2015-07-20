#import "AdvancedPlayer.h"
#import "Definition.h"
#import "Drawing.h"

#import "PGMidi/PGMidi.h"
#import "PGMidi/PGArc.h"
#import "PGMidi/iOSVersionDetection.h"

#import "MIDINote.h"

@interface AdvancedPlayer ()  {
    
    BOOL longPressed;
    
    /****** Drawing Elements ******/
    UInt16 Brush;
    CGFloat Red;
    CGFloat Green;
    CGFloat Blue;
    CGFloat Opacity;
    
    CGFloat width;
    CGFloat height;
    CGFloat gridWidth;
    CGFloat gridHeight;
    UInt16 GridIdx;
    
    /****** MIDINotes ******/
    UIButton *keys[36];
    UInt8 MIDINoteNumberArray[36];
    
    /******Dynamics ******/
    CGRect SliderRect;
    UInt8 velocity;
    float velocityMin;
    float velocityMax;
    UInt8 currentPage;
}

/******ViewController elements ******/
/* SimpleButton: to return to simple mode */
@property (strong, nonatomic) IBOutlet UIButton *SimpleButton;
/* Button1 - 3 is for flipping between different octaves(pages in the view) */
@property (strong, nonatomic) IBOutlet UIButton *Button1;
@property (strong, nonatomic) IBOutlet UIButton *Button2;
@property (strong, nonatomic) IBOutlet UIButton *Button3;
/* The ButtonV is for change velocity */
@property (strong, nonatomic) IBOutlet UIButton *ButtonV;
@property (strong, nonatomic) IBOutlet UIImageView *mainImage;
@property (strong, nonatomic) IBOutlet UIImageView *SideImage;
@property (strong, nonatomic) IBOutlet UILabel *feedbackLabel;
/* a Timer used for drawing the grid */
@property (nonatomic, retain) NSTimer *draw;

/*****Communication Infrastructure *****/
@property (readonly) NoteNumDict *Dict;
@property (readwrite) NSMutableArray *MIDINoteNameArray;
@property (readwrite) NSMutableArray *MIDINoteArray;

@end

@implementation AdvancedPlayer

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:NO];
    _SimpleButton.alpha = 0;
    _Button1.alpha = 0;
    _Button2.alpha = 0;
    _Button3.alpha = 0;
    _ButtonV.alpha = 0;
    _feedbackLabel.alpha = 0;
    
    velocity = 80;
    currentPage = 0;
    [self infrastructureSetup];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:NO];
    [UIView animateWithDuration:2 animations:^{_Button1.alpha = 1, _Button2.alpha = 1; _Button3.alpha = 1; _ButtonV.alpha = 1;}];
    [self viewInit];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Setup Routine

- (void) viewInit {
    longPressed = false;
    Brush = 3;
    Red = 1;
    Green = 1;
    Blue = 1;
    Opacity = 1;
    width = self.mainImage.frame.size.width;
    height = self.mainImage.frame.size.height;
    gridWidth = width / GridSize;
    gridHeight = height / GridSize;
    GridIdx = 0;
    
    // Draw a grid
     [self placeButtons];
    _draw = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(drawGrid) userInfo:nil repeats:YES];
    
    velocityMin = _Button3.frame.origin.y + _Button3.frame.size.height + 25;
    velocityMax = _SideImage.frame.size.height - 25;
    SliderRect = CGRectMake(0, velocityMin, 30, velocityMax - velocityMin);
}

- (void) infrastructureSetup {
    if (_Dict == nil) {
        _Dict = [[NoteNumDict alloc] init];
    }
    if (_MIDINoteNameArray == nil) {
        _MIDINoteNameArray = [[NSMutableArray alloc] initWithObjects:
                          @"E4", @"B3", @"G3", @"D3", @"A2", @"E2",
                          @"F4", @"C4", @"G#3", @"D#3", @"A#2", @"F2",
                          @"F#4", @"C#4", @"A3", @"E3", @"B2", @"F#2",
                          @"G4", @"D4", @"A#3", @"F3", @"C3", @"G2",
                          @"G#4", @"D#4", @"B3", @"F#3", @"C#3", @"G#2",
                          @"A4", @"E4", @"C4", @"G3", @"D3", @"A2", nil];
    }
    if (_MIDINoteArray == nil) {
        _MIDINoteArray = [[NSMutableArray alloc] init];
        UInt8 idx = 0;
        for (NSString *NoteName in _MIDINoteNameArray) {
            NSNumber *NoteNumber = [_Dict.Dict objectForKey:NoteName];
            UInt8 note = [NoteNumber unsignedCharValue];
            MIDINoteNumberArray[idx] = note;
            MIDINote *M = [[MIDINote alloc] initWithNote:note duration:1 channel:*(_playerChannel) velocity:velocity SysEx:0 Root:*(_playerID)];
            [_MIDINoteArray addObject:M];
            idx++;
        }
    }
}

#pragma mark - Velocity Slider
- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.view];
    
    Slide(SliderRect, currentPoint, _ButtonV);
    [self velocityChanged];
}

static void Slide (CGRect Rect, CGPoint currentPoint, UIButton *Button) {
    if (CGRectContainsPoint(Rect, currentPoint)) {
        DSLog(@"pointInside");
        [Button setCenter:CGPointMake(Button.center.x, currentPoint.y)];
    }
}

- (void) velocityChanged {
    CGFloat centerY = _ButtonV.center.y;
    float tempVel = 1 - (centerY - velocityMin) / (velocityMax - velocityMin);
    tempVel = tempVel * 127;
    velocity = floor(tempVel);
}

#pragma mark - Side Button
/****** Changing Octaves ******/
- (IBAction)page:(id)sender {
    UIButton *Button = (UIButton *)sender;
    UInt8 page = Button.tag;
    UInt8 currentNote, newNote;
    if (page > currentPage) {
        UInt8 pagediff = page - currentPage;
        NSLog(@"Pagediff %d", pagediff);
        for (UInt8 idx = 0; idx <36; idx++) {
            currentNote = MIDINoteNumberArray[idx];
            NSLog(@"currentNote %d", currentNote);
            newNote = currentNote + pagediff*6;
            NSLog(@"newNote %d", newNote);
            NSNumber *newNoteNum = [NSNumber numberWithChar:newNote];
            NSArray *newNoteNameArr = [_Dict.Dict allKeysForObject:newNoteNum];
            NSString *newNoteName = [newNoteNameArr objectAtIndex:0];
            NSLog(@"currentNoteName %@", [_MIDINoteNameArray objectAtIndex:idx]);
            NSLog(@"newNoteName %@", newNoteName);
            MIDINoteNumberArray[idx] = newNote;
            [_MIDINoteNameArray replaceObjectAtIndex:idx withObject:newNoteName];
        }
    } else if (page < currentPage) {
        UInt8 pagediff = currentPage - page;
        for (UInt8 idx = 0; idx <36; idx++) {
            currentNote = MIDINoteNumberArray[idx];
            newNote = currentNote - pagediff*6;
            NSNumber *newNoteNum = [NSNumber numberWithChar:newNote];
            NSArray *newNoteNameArr = [_Dict.Dict allKeysForObject:newNoteNum];
            NSString *newNoteName = [newNoteNameArr objectAtIndex:0];
            MIDINoteNumberArray[idx] = newNote;
            [_MIDINoteNameArray replaceObjectAtIndex:idx withObject:newNoteName];
        }
    }
    currentPage = page;
    [self performSelectorInBackground:@selector(placeButtons) withObject:nil];
}

#pragma mark - feedback
- (void) feebackAnimatewithString:(NSString *)feedback {
    _feedbackLabel.alpha = 0;
    _feedbackLabel.text = feedback;
    [UIView animateWithDuration:1 animations:^{_feedbackLabel.alpha = 1;}];
    [UIView animateWithDuration:1 delay:1 options:UIViewAnimationOptionTransitionCurlUp animations:^{_feedbackLabel.alpha = 0;} completion:NO];
}

#pragma mark - Drawing

- (void) drawGrid {
    // Draw the side Grid
    if (GridIdx == 1) {
        [Drawing drawLineWithPreviousPoint:CGPointMake(0, 0) CurrentPoint:CGPointMake(0, height) onImage:self.SideImage withbrush:Brush Red:Red Green:Green Blue:Blue Alpha:Opacity Size:self.SideImage.frame.size];
        [Drawing drawLineWithPreviousPoint:CGPointMake(0, height) CurrentPoint:CGPointMake(30, height) onImage:self.SideImage withbrush:Brush Red:Red Green:Green Blue:Blue Alpha:Opacity Size:self.SideImage.frame.size];
    }
    // Draw a 6 by 6 Grid
    [Drawing drawLineWithPreviousPoint:CGPointMake(gridWidth*GridIdx, 0) CurrentPoint:CGPointMake(gridWidth*GridIdx, height) onImage:self.mainImage withbrush:Brush Red:Red Green:Green Blue:Blue Alpha:Opacity Size:self.mainImage.frame.size];
    [Drawing drawLineWithPreviousPoint:CGPointMake(0, gridHeight*GridIdx) CurrentPoint:CGPointMake(width, gridHeight*GridIdx) onImage:self.mainImage withbrush:Brush Red:Red Green:Green Blue:Blue Alpha:Opacity Size:self.mainImage.frame.size];
    if(GridIdx++ == 6) {
        [_draw invalidate];
        GridIdx = 0;
    }
}

- (void) placeButtons {
    for (int i = 0; i < GridSize; i++) {
        for (int j = 0 ; j < GridSize; j++) {
            UIButton *thisButton = keys[i*GridSize + j];
            if (thisButton != nil) {
                [thisButton removeFromSuperview];
                thisButton = nil;
            }
            thisButton = [UIButton buttonWithType:UIButtonTypeCustom];
            thisButton.frame = CGRectMake(i*gridWidth + AdvancePlayerSideMargin, j*gridHeight, gridWidth , gridHeight);
            [thisButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            thisButton.showsTouchWhenHighlighted = true;
            thisButton.tag = i*GridSize + j;
            //[thisButton setTitle:[NSString stringWithFormat:@"%d, %d", i, j] forState:UIControlStateNormal];
            [thisButton setTitle:[NSString stringWithFormat:@"%@", [_MIDINoteNameArray objectAtIndex:thisButton.tag]] forState:UIControlStateNormal];
            thisButton.titleLabel.font = [UIFont fontWithName:@"Trebuchet MS" size:18];
            [thisButton addTarget:self action:@selector(keyPressed:) forControlEvents:UIControlEventTouchUpInside];
            [thisButton addTarget:self action:@selector(keyUpPressed:) forControlEvents:UIControlEventTouchDown];
            [self.view addSubview:thisButton];
            [self.view sendSubviewToBack:thisButton];
            keys[i*GridSize + j] = thisButton;
        }
    }
}

#pragma mark - Playing
// mousePressed
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (longPressed) {
        longPressed = false;
        [UIView animateWithDuration:1 animations:^{self.SimpleButton.alpha = 0.0;}];
    }
}

- (void)keyPressed:(id)sender {
    UIButton *thisButton = (UIButton *)sender;
    NSInteger tag = thisButton.tag;
    DSLog(@"keyPressed with button Tag: %d", tag);
    [self playAtTag:tag];
}

- (void)keyUpPressed:(id)sender {
    // Dismiss the simple mode selector
    if (longPressed) {
        longPressed = false;
        [UIView animateWithDuration:1 animations:^{self.SimpleButton.alpha = 0.0;}];
    }
}

/****** The function for actually sending out performance ******/
- (void)playAtTag:(NSInteger)tag {
    if (*_playerEnabled) {
        MIDINote *M = [_MIDINoteArray objectAtIndex:tag];
        // Set everytime in case it will miss channel change.
        [M setNote:MIDINoteNumberArray[tag]];
        [M setChannel:*(_playerChannel)];
        [M setID:*(_playerID)];
        [M setVelocity:velocity];
        
        [_CMU sendMidiData:M];
    }
}

#pragma mark - dismiss Advanced Player

- (IBAction)backToSimple:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
    [UIView animateWithDuration:1 animations:^{self.SimpleButton.alpha =0;}];
}

#pragma mark - Gesture Recognizer

/****** Showing the simple button ******/
- (IBAction)LongPressed:(id)sender {
    DSLog(@"LongPressed");
    longPressed = true;
    [UIView animateWithDuration:1 animations:^{self.SimpleButton.alpha = 1;}];
}

@end
