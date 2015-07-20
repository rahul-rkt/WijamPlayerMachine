#import "mainViewController.h"
#import "Definition.h"

#import "PGMidi/PGMidi.h"
#import "PGMidi/PGArc.h"
#import "PGMidi/iOSVersionDetection.h"

#import "MIDINote.h"
#import "Communicator.h"

@interface mainViewController () {
    UInt16 detectConnectedCounter;
    BOOL detectConnectedDeviceEnable;
    BOOL masterConnected;
}
@property (strong, nonatomic) IBOutlet UILabel *WI;
@property (strong, nonatomic) IBOutlet UIButton *JAM;
@property (strong, nonatomic) IBOutlet UIButton *Refresh;

/****** Network Service related declaraion ******/
@property (strong, nonatomic) NSMutableArray *services;
@property (strong, nonatomic) NSNetServiceBrowser *serviceBrowser;
@property (strong, nonatomic) MIDINetworkSession *Session;
/* Timer for periodically scanning connected devices */
@property (nonatomic, retain) NSTimer *connectTimer;

/****** UI Objects ******/
@property (strong, nonatomic) IBOutlet UILabel *masterName;
@property (strong, nonatomic) NSMutableArray *deviceArray;
@property (strong, nonatomic) IBOutlet UIButton *Down;

/* master selection*/
@property (assign, atomic) UInt16 masterIdx;


@end

@implementation mainViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:NO];
    self.WI.alpha = 0; self.JAM.alpha = 0; self.masterName.alpha = 0;  self.Down.alpha = 0; self.Refresh.alpha = 0;
    [UIView animateWithDuration:2 animations:
     ^{self.WI.alpha = 1; self.JAM.alpha = 1; self.masterName.alpha = 1;  self.Down.alpha = 1; self.Refresh.alpha = 1;}];
}

- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"ViewDidAppear");
    [super viewDidAppear:NO];
    _masterIdx = 0;
    _deviceArray = [NSMutableArray arrayWithObjects:@"...", nil];
    _masterName.text = [_deviceArray objectAtIndex:_masterIdx];
    [self removeAllConnections];
    [self configureNetworkSessionAndServiceBrowser];
    _connectTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(scanServices) userInfo:nil repeats:YES];
    detectConnectedCounter = 0;
    detectConnectedDeviceEnable = false;
    masterConnected = false;
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

#pragma mark - network Service
/****** Thanks for CX's participation in this part ******/
- (void) configureNetworkSessionAndServiceBrowser {
    // configure network session
    if (_Session == nil) {
        _Session = [MIDINetworkSession defaultSession];
        _Session.enabled = true;
        _Session.connectionPolicy = MIDINetworkConnectionPolicy_NoOne;
    }
    
    // configure service browser
    if (self.services == nil) {
        self.services = [[NSMutableArray alloc] init];
    }
    
    if (self.serviceBrowser == nil) {
        self.serviceBrowser = [[NSNetServiceBrowser alloc] init];
        [self.serviceBrowser setDelegate:self];
        // starting scanning for services (won't stop until stop() is called)
        [self.serviceBrowser searchForServicesOfType:MIDINetworkBonjourServiceType inDomain:@"local."];
    }
}

- (void) netServiceBrowser:(NSNetServiceBrowser*)serviceBrowser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing {
    // Also add self service, but ensure that service with a same name can also be added
    NSLog(@"didFindService.................................. %@", service.name);
    [self.services addObject:service];
}

- (void) netServiceBrowser:(NSNetServiceBrowser*)serviceBrowser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing {
    NSLog(@"didRemoveService..................................%@", service.name);
    MIDINetworkHost *host = [MIDINetworkHost hostWithName:[service name] netService:service];
    MIDINetworkConnection *connection = [MIDINetworkConnection connectionWithHost:host];
    if (connection) {
        [_Session removeConnection:connection]; // remove connection automatically
    }
    [self.services removeObject:service];
}

- (void) removeAllConnections {
    for (NSNetService *Service in self.services) {
        MIDINetworkHost *Host = [MIDINetworkHost hostWithName:Service.name netService:Service];
        [_Session removeContact:Host];
        MIDINetworkConnection *Con = [MIDINetworkConnection connectionWithHost:Host];
        if (Con) {
            [_Session removeConnection:Con];
        }
    }
}

- (IBAction)Refresh:(id)sender {
    [self removeAllConnections];
    [self.services removeAllObjects];
    _serviceBrowser = nil;
    _Session = nil;

    [self configureNetworkSessionAndServiceBrowser];
 
}

#pragma mark - master selection

- (void) detectConnectedDevices {
    if (detectConnectedCounter++ >2) {
        detectConnectedCounter = 0;
        if (_Session.connections.count > 0) {
            masterConnected = true;
            NSLog(@"Connected......");
        } else {
            masterConnected = false;
        }
    }
}

- (void) scanServices {
    if (detectConnectedDeviceEnable) {
        [self detectConnectedDevices];
    }
    
    [_deviceArray removeAllObjects];
    for (NSNetService *Service in self.services) {
        DSLog(@"name: %@", Service.name);
        [_deviceArray addObject:Service.name];
    }
    [_deviceArray addObject:@"..."];
}

/****** Choosing Master ******/
- (IBAction)masterDown:(id)sender {
    if (_deviceArray.count > 0) {
        if (_masterIdx + 1 <_deviceArray.count) {
            _masterIdx++;
            _masterName.text = [_deviceArray objectAtIndex:_masterIdx];
        } else {
            _masterIdx = 0;
            _masterName.text = [_deviceArray objectAtIndex:_masterIdx];
        }
    }
}

#pragma mark - Segue functions
- (IBAction)JAM:(id)sender {
    // Select the connection shown in the masterName label
    detectConnectedDeviceEnable = true;
    for (NSNetService *Service in self.services) {
        MIDINetworkHost *host = [MIDINetworkHost hostWithName:Service.name netService:Service];
        if ([host.name isEqualToString:_masterName.text]) {
            NSLog(@"try to connect to: %@", host.name);
            MIDINetworkConnection *conn = [MIDINetworkConnection connectionWithHost:host];
            [_Session addConnection:conn];
        }
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    PlayerMachineViewController *playerMachineVC = (PlayerMachineViewController *)segue.destinationViewController;
    playerMachineVC.masterConnected = &masterConnected;
}

@end
