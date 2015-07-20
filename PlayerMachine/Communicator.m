#import "Communicator.h"

#import "MIDINote.h"
#import "NoteNumDict.h"

#import "PGMidi/PGMidi.h"
#import "PGMidi/PGArc.h"
#import "PGMidi/iOSVersionDetection.h"
#import <CoreMIDI/CoreMIDI.h>

@interface Communicator() <PGMidiDelegate, PGMidiSourceDelegate>

@property (readonly) NoteNumDict *Dict;

- (void) sendMidiDataInBackground:(MIDINote *)midinote;

@end

@implementation Communicator

-(id)init {
    self = [super init];
    if (self) {
        _midi = nil;
        if (_Dict == nil)
            _Dict = [[NoteNumDict alloc] init];
        
        return self;
    }
    return nil;
}

- (void) dealloc {
    _midi = nil;
    _Dict = nil;
}

#pragma mark IBActions

- (void) sendMidiData:(MIDINote *)midinote
{
    [self performSelectorInBackground:@selector(sendMidiDataInBackground:) withObject:midinote];
}

#pragma mark Shenanigans

- (void) attachToAllExistingSources
{
    for (PGMidiSource *source in _midi.sources)
    {
        [source addDelegate:self];
    }
}

- (void) setMidi:(PGMidi*)m
{
    _midi.delegate = nil;
    _midi = m;
    _midi.delegate = self;
    
    [self attachToAllExistingSources];
}


NSString *StringFromPacket(const MIDIPacket *packet)
{
    // Note - this is not an example of MIDI parsing. I'm just dumping
    // some bytes for diagnostics.
    // See comments in PGMidiSourceDelegate for an example of how to
    // interpret the MIDIPacket structure.
    return [NSString stringWithFormat:@"  %u bytes: [%02x,%02x,%02x, %02x,%02x,%02x, %02x,%02x,%02x, %02x, %02x]",
            packet->length,
            (packet->length > 0) ? packet->data[0] : 0,
            (packet->length > 1) ? packet->data[1] : 0,
            (packet->length > 2) ? packet->data[2] : 0,
            (packet->length > 3) ? packet->data[3] : 0,
            (packet->length > 4) ? packet->data[4] : 0,
            (packet->length > 5) ? packet->data[5] : 0,
            (packet->length > 6) ? packet->data[6] : 0,
            (packet->length > 7) ? packet->data[7] : 0,
            (packet->length > 8) ? packet->data[8] : 0,
            (packet->length > 9) ? packet->data[9] : 0,
            (packet->length > 10) ? packet->data[10] : 0
            ];
}

/****** These four methods are required by PGMidiDelegate ******/
- (void) midi:(PGMidi*)midi sourceAdded:(PGMidiSource *)source
{
    [source addDelegate:self];
}

- (void) midi:(PGMidi*)midi sourceRemoved:(PGMidiSource *)source
{
}

- (void) midi:(PGMidi*)midi destinationAdded:(PGMidiDestination *)destination
{
}

- (void) midi:(PGMidi*)midi destinationRemoved:(PGMidiDestination *)destination
{
}

/****** midiReceived delegate ******/
- (void) handlemidiReceived:(const MIDIPacket *)packet {
    NSLog(@"handlemidiReceived:");
    [[self AssignmentDelegate] MIDIAssignment:packet];
}

// This is require by PGMidiSourceDelegate protocol. It is for MIDI packet receiving.
- (void) midiSource:(PGMidiSource*)midi midiReceived:(const MIDIPacketList *)packetList
{
    const MIDIPacket *packet = &packetList->packet[0];
    for (int i = 0; i < packetList->numPackets; ++i)
    {
#ifdef COMTEST
        NSLog(@"MIDI received:");
        NSLog(@"%@", StringFromPacket(packet));
#endif
        
        [self handlemidiReceived:packet];
        packet = MIDIPacketNext(packet);
    }
}

/****** send notes and ID at the same time ******/
- (void) sendMidiDataInBackground:(id)midinote {
    MIDINote *midiNote = midinote;
    NSLog(@"Slave Send Normal Note");
    const UInt8 notetype = midiNote.Root;
    const UInt8 channel = [midiNote channel];
    const UInt8 note      = [midiNote note];
    const UInt8 ID = midiNote.ID;
    const UInt8 noteSysEx[] = {0xF0, 0x7D, ID, 0xF7};
    const UInt8 noteOn[]  = { 0x90|channel, note, [midiNote velocity]};
    const UInt8 noteOff[] = { 0x80|channel, note, 0};
    const UInt8 noteArr[] = {notetype | channel, note, [midiNote velocity]};
    
    if(midiNote.channel == Ensemble) {
        [_midi sendBytes:noteArr size:sizeof(noteArr)];
        [_midi sendBytes:noteSysEx size:sizeof(noteSysEx)];
    } else {
        [_midi sendBytes:noteOn size:sizeof(noteOn)];
        [_midi sendBytes:noteSysEx size:sizeof(noteSysEx)];
        [NSThread sleepForTimeInterval:1.5]; // last for 1s
        [_midi sendBytes:noteOff size:sizeof(noteOff)];
    }
}


@end
