//
//  ViewController.m
//  SDWebRTC
//
//  Created by Sana Desai on 2019-12-29.
//  Copyright © 2019 Sana Desai. All rights reserved.
//

#import "ViewController.h"
#import "WebRTC/WebRTCClient.h"
#import <SIOSocket/SIOSocket.h>

@interface ViewController () < WebRTCClientDelegate > {
    NSString *ipAdress;
    BOOL socketIsConnected, isCaller;
    WebRTCClient *webRTCClient;
    SIOSocket *my_socket;
    NSDictionary *remoteSDP;
}
@property (weak, nonatomic) IBOutlet UIView *remoteVideoViewContainter;
//@property (weak, nonatomic) IBOutlet UIView *localVideoView;

@end

@implementation ViewController

-(void) connectSocketWithCompletionHandler:(void (^)(BOOL success, NSString *errMsg))completion
{
    [SIOSocket socketWithHost: [NSString stringWithFormat:@"ws://%@:8080", ipAdress] response: ^(SIOSocket *socket)
     {
        self->my_socket = socket;
        
        self->my_socket.onConnect = ^()
        {
            self->socketIsConnected = YES;
            
            completion(YES, @"suc");
        };
        
        self->my_socket.onDisconnect = ^()
        {
            self->socketIsConnected = FALSE;
            NSLog(@"SOCKET: Socket has Disconnected!");
            
            completion(NO, @"failed");
        };
        
        self->my_socket.onError = ^(NSDictionary *err)
        {
            self->socketIsConnected = FALSE;
            completion(NO,@"error");
            NSLog(@"SOCKET: ERROR - %@", err);
        };
        
        self->my_socket.onReconnect = ^(NSInteger numberOfAttempts)
        {
            NSLog(@"SOCKET: Reconnecting - %ld", (long)numberOfAttempts);
        };
        
        self->my_socket.onReconnectionAttempt = ^(NSInteger numberOfAttempts)
        {
            NSLog(@"SOCKET: Reconnecting Attempt - %ld", (long)numberOfAttempts);
        };
        
        self->my_socket.onReconnectionError = ^(NSDictionary *err)
        {
            NSLog(@"SOCKET: Reconnect ERROR - %@", err);
        };
        
        [self->my_socket on: @"oncandidate"
                   callback: ^(SIOParameterArray *args)
         {
            [self CandidateRecieved:[NSDictionary dictionaryWithObjectsAndKeys:args, @"data", nil]];
        }];
        
        [self->my_socket on: @"IncomingVideoChatRequest" callback: ^(SIOParameterArray *args)
         {
            [self IncomingVideoChatRequest:[NSDictionary dictionaryWithObjectsAndKeys:args, @"data", nil]];
        }];
        
        [self->my_socket on: @"RejectedVideoChat" callback: ^(SIOParameterArray *args)
         {
            [self RejectedVideoChat:[NSDictionary dictionaryWithObjectsAndKeys:args, @"data", nil]];
        }];
        
        [self->my_socket on: @"EndVideoChat" callback: ^(SIOParameterArray *args)
         {
            [self EndVideoChat:[NSDictionary dictionaryWithObjectsAndKeys:args, @"data", nil]];
        }];
        
        [self->my_socket on: @"TimeOutVideoChat" callback: ^(SIOParameterArray *args)
         {
            [self TimeOutVideoChat:[NSDictionary dictionaryWithObjectsAndKeys:args, @"data", nil]];
        }];
        
        [self->my_socket on: @"StartVideoChat" callback: ^(SIOParameterArray *args)
         {
            [self StartVideoChat:[NSDictionary dictionaryWithObjectsAndKeys:args, @"data", nil]];
        }];
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    socketIsConnected = NO;
    ipAdress = @"http://localhost"; //change acc to yours
    
    webRTCClient = [[WebRTCClient new] init];
    webRTCClient.delegate = self;
    [webRTCClient setupWithVideo:YES Audio:YES dataChannel:YES];
    
    [self connectSocketWithCompletionHandler:^(BOOL success, NSString *errMsg) {
        self->socketIsConnected = success;
    }];
}

-(void)viewDidAppear:(BOOL)animated {
    //init both views
    UIView* localVideoView = [webRTCClient localVideoView];
    [webRTCClient setupLocalViewFrame:CGRectMake(0, 0, self.view.frame.size.width/3, self.view.frame.size.height/3)];
    [self.view addSubview:localVideoView];
    
    UIView *remoteVideoView = [webRTCClient remoteVideoView];
    [webRTCClient setupRemoteViewFrame:self.remoteVideoViewContainter.frame];
    remoteVideoView.center = self.remoteVideoViewContainter.center;
    [self.remoteVideoViewContainter addSubview:remoteVideoView];
}

#pragma mark - UI Events

- (IBAction)Call:(id)sender {
    if (!webRTCClient.isConnected) {
        [webRTCClient connect:^(RTCSessionDescription *offerSDP) {
            self->isCaller = YES;
            [self sendSDP:offerSDP];
        }
         ];
    }
}

- (IBAction)endCall:(id)sender {
    if (webRTCClient.isConnected) {
        [webRTCClient disconnect];
    }
}

#pragma mark - WebRTC Signaling

-(void)sendSDP:(RTCSessionDescription*)sessionDescription {
    
    NSString *type = @"";
    if (sessionDescription.type == RTCSdpTypeOffer) {
        type = @"offer";
    }
    else if (sessionDescription.type == RTCSdpTypeAnswer) {
        type = @"answer";
    }
    
    if (isCaller) {
        NSDictionary *param = @{
            @"recipient" : [NSNumber numberWithInt:750],//friend
            @"initiator" : [NSNumber numberWithInt:748],//myself
            @"sdpinfo": @{@"type" : type,
                          @"sdp" : sessionDescription.sdp
            }
        };
        SIOParameterArray *myArray = [SIOParameterArray arrayWithObject:param];
        [my_socket emit: @"NewVideoChatRequest" args:myArray];
    }
    else {
        //send sdp request
        NSDictionary *param = @{
            @"recipientId" : [NSNumber numberWithInt:750],//friend
            @"sdpinfo": @{@"type" : type,
                          @"sdp" : sessionDescription.sdp
            }
        };
        SIOParameterArray *myArray = [SIOParameterArray arrayWithObject:param];
        [my_socket emit:@"AcceptVideoChat" args:myArray];
    }
}

-(void)sendCandidate:(RTCIceCandidate*) iceCandidate {
    NSDictionary *param = @{
        @"candidate" : @{
                @"candidate" : iceCandidate.sdp,
                @"sdpMid" : iceCandidate.sdpMid,
                @"sdpMLineIndex" : [NSNumber numberWithInt: iceCandidate.sdpMLineIndex]
        },
        @"recipient" : [NSNumber numberWithInteger:750]//friend
    };
    SIOParameterArray *myArray = [SIOParameterArray arrayWithObject:param];
    [my_socket emit:@"candidate" args:myArray];
}

#pragma MARK - WebRTCClient Delegate
-(void)didGenerateCandidate:(RTCIceCandidate *)iceCandidate {
    [self sendCandidate:iceCandidate];
}

-(void)didIceConnectionStateChanged:(RTCIceConnectionState)iceConnectionState {
    NSLog(@"Webrtc statud:%ld", (long)iceConnectionState);
}

-(void)didConnectWebRTC {
    NSLog(@"WebRTC CONNECTED");
}

-(void)didDisconnectWebRTC {
    NSLog(@"WebRTC DIS-CONNECTED");
}

-(void)didOpenDataChannel {
    NSLog(@"did open data channel");
}

-(void)didReceiveData:(NSData *)data {
    NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}

-(void)didReceiveMessage:(NSString *)message {
    NSLog(@"%@", message);
}

- (void)endVideoCall
{
    [self endCall:self];
}

#pragma mark - Video Chat Observers
- (void)UnRegisterObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)IncomingVideoChatRequest:(NSDictionary *)notification
{
    NSLog(@"IncomingVideoChat %@",[notification objectForKey:@"data"]);
    NSArray *args = [notification objectForKey:@"data"];
    
    //show accept/reject alert
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Incoming Video Call" message:@"Your friend is calling you!" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* acceptAction = [UIAlertAction actionWithTitle:@"ACCEPT" style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {
        //add remote sdp in local dict
        self->isCaller  = NO;
        self->remoteSDP = [NSDictionary dictionaryWithDictionary:[[args objectAtIndex:0] objectForKey:@"sdpinfo"]];
        
        RTCSdpType type;
        if ([[self->remoteSDP objectForKey:@"type"] isEqual: @"offer"]) {
            type = RTCSdpTypeOffer;
        }
        else {
            type = RTCSdpTypeAnswer;
            //not proper response. We need "offer"
            //Handle here
            return;
        }
        
        [self->webRTCClient receiveOffer:[[RTCSessionDescription new] initWithType:type sdp:[self->remoteSDP objectForKey:@"sdp"]] onCreateAnswer:^(RTCSessionDescription *onCreateAnswer) {
            [self sendSDP:onCreateAnswer];
        }];
    }];
    
    [alert addAction:acceptAction];
    
    UIAlertAction* rejectAction = [UIAlertAction actionWithTitle:@"REJECT" style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {
        
    }];
    
    [alert addAction:rejectAction];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)CandidateRecieved:(NSDictionary *)notification
{
    NSLog(@"Remote Candidate Recieved %@",[notification  objectForKey:@"data"]);
    NSDictionary *ice_candidate = [[[notification objectForKey:@"data"] objectAtIndex:0]objectForKey:@"candidate"];
    
    RTCIceCandidate *candidate = [[RTCIceCandidate new] initWithSdp:ice_candidate[@"candidate"] sdpMLineIndex: [ice_candidate[@"sdpMLineIndex"] intValue] sdpMid:ice_candidate[@"sdpMid"]];
    
    [webRTCClient receiveCandidate:candidate];
}

- (void)StartVideoChat:(NSDictionary *)notification
{
    NSLog(@"StartVideoChat %@",[notification objectForKey:@"data"]);
    
    if (isCaller) {
        RTCSdpType type;
        if ([remoteSDP[@"type"] isEqual: @"offer"]) {
            type = RTCSdpTypeOffer;
            //not proper response. We need "answer"
            //Handle here
            return;
        }
        else {
            type = RTCSdpTypeAnswer;
        }
        [webRTCClient receiveAnswer:[[RTCSessionDescription new] initWithType:type sdp:remoteSDP[@"sdp"]]];
    }
}

- (void)RejectedVideoChat:(NSDictionary *)notification
{
    NSLog(@"RejectedVideoChat %@",[notification objectForKey:@"data"]);
}

- (void)EndVideoChat:(NSDictionary *)notification
{
    NSLog(@"EndVideoChat %@",[notification objectForKey:@"data"]);
    [self endVideoCall];
}

- (void)TimeOutVideoChat:(NSDictionary *)notification
{
    NSLog(@"TimeOutVideoChat %@",[notification objectForKey:@"data"]);
}

@end

