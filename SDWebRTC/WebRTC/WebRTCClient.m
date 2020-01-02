//
//  WebRTCClient.m
//  SDWebRTC
//
//  Created by Sana Desai on 2019-12-29.
//  Copyright © 2019 Sana Desai. All rights reserved.
//

#import "WebRTCClient.h"

@implementation WebRTCClient

-(UIView *)localVideoView {
    //DO2
    return self.localView;
}

-(UIView *)remoteVideoView {
    return self.remoteView;
}

-(instancetype)init {
    self = [super init];
    self.channels = (NSMutableDictionary *)@{
        @"video" : @NO,
        @"audio" : @NO,
        @"datachannel" : @NO,
    };
    
    NSLog(@"WebRTC Client initialize");
    return self;
}

-(void)dealloc {
    NSLog(@"WebRTC Client Deinit");
    self.peerConnectionFactory = nil;
    self.peerConnection = nil;
}

#pragma mark- Public Functions
-(void)setupWithVideo:(BOOL)videoTrack Audio:(BOOL)audioTrack dataChannel:(BOOL)dataChannel {
    
    NSLog(@"Set up");
    
    self.channels = [[NSMutableDictionary alloc] initWithObjects:@[@(videoTrack), @(audioTrack), @(dataChannel)] forKeys:@[@"video", @"audio", @"datachannel"]];
        
    RTCDefaultVideoEncoderFactory *videoEncoderFactory = [RTCDefaultVideoEncoderFactory new];
    RTCDefaultVideoDecoderFactory *videoDecoderFactory = [RTCDefaultVideoDecoderFactory new];
    
    self.peerConnectionFactory = [[RTCPeerConnectionFactory
                                  alloc]initWithEncoderFactory:videoEncoderFactory decoderFactory:videoDecoderFactory];
    
    [self setupView];
    [self setupLocalTracks];
    
    if (self.channels[@"video"]) {
        [self startCaptureLocalVideoWithCamPosition:AVCaptureDevicePositionFront videoWidth:640 videoHeight:640*16/9 videoFPS:30];
        [self.localVideoTrack addRenderer:self.localRenderView];
    }
}

-(void)setupLocalViewFrame:(CGRect)frame {
    //DO3
    self.localView.frame = frame;
    self.localRenderView.frame = self.localView.frame;
}

-(void)setupRemoteViewFrame:(CGRect)frame {
    self.remoteView.frame = frame;
    self.remoteRenderView.frame = self.remoteView.frame;
}

#pragma mark - Connect
-(void)connect:(void(^)(RTCSessionDescription*))onSuccess {
    self.peerConnection = [self setupPeerConnection];
    self.peerConnection.delegate = self;
    
    if (self.channels[@"video"]) {
        [self.peerConnection addTrack:self.localVideoTrack streamIds:@[@"stream0"]];
    }
    if (self.channels[@"audio"]) {
        [self.peerConnection addTrack:self.localAudioTrack streamIds:@[@"stream0"]];
    }
    if (self.channels[@"datachannel"]) {
        self.dataChannel = [self setupDataChannel];
        self.dataChannel.delegate = self;
    }
    
    [self makeOffer:onSuccess];
}

#pragma mark - Hang Up
-(void)disconnect {
    if (self.peerConnection) {
        [self.peerConnection close];
    }
}

#pragma mark - Signaling Event
-(void)receiveOffer:(RTCSessionDescription*)offerSDP onCreateAnswer:(void(^)(RTCSessionDescription*))onCreateAnswer {
    if (self.peerConnection == nil) {
        NSLog(@"offer received, create peerconnection");
        self.peerConnection = [self setupPeerConnection];
        self.peerConnection.delegate = self;
        
        if (self.channels[@"video"]) {
            [self.peerConnection addTrack:self.localVideoTrack streamIds:@[@"stream-0"]];
        }
        if (self.channels[@"audio"]) {
            [self.peerConnection addTrack:self.localAudioTrack streamIds:@[@"stream-0"]];
        }
        if (self.channels[@"datachannel"]) {
            self.dataChannel = [self setupDataChannel];
            self.dataChannel.delegate = self;
        }
    }
    
    NSLog(@"Set Remote Description");
    __weak typeof(self) weakSelf = self;
    [self.peerConnection setRemoteDescription:offerSDP completionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"failed to set remote offer SDP: %@", error);
            return;
        }
        
        NSLog(@"succeed to set remote offer SDP");
        [weakSelf makeAnswer:onCreateAnswer];
    }];
}

-(void)receiveAnswer:(RTCSessionDescription*)answerSDP {
    [self.peerConnection setRemoteDescription:answerSDP completionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"failed to set remote offer SDP: %@", error);
            return;
        }
    }];
}

-(void)receiveCandidate:(RTCIceCandidate*)candidate {
    [self.peerConnection addIceCandidate:candidate];
}

#pragma mark - Private Functions
#pragma mark - Setup
-(RTCPeerConnection*)setupPeerConnection {
    RTCConfiguration *rtcConf = [RTCConfiguration new];
    rtcConf.iceServers = @[[[RTCIceServer alloc] initWithURLStrings:@[@"stun:stun.l.google.com:19302"]]];
    RTCMediaConstraints *mediaConstraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:nil];
    RTCPeerConnection *pc = [self.peerConnectionFactory peerConnectionWithConfiguration:rtcConf constraints:mediaConstraints delegate:nil];
    return pc;
}

-(void)setupView {
    //local
    //DO1
    self.localRenderView = [[RTCEAGLVideoView alloc]init];
    self.localRenderView.delegate = self;
    self.localView = [[UIView alloc] init];
    self.localView.backgroundColor = [UIColor greenColor];
    [self.localView addSubview:self.localRenderView];
    
    //remote
    self.remoteRenderView = [[RTCEAGLVideoView alloc]init];
    self.remoteRenderView.delegate = self;
    self.remoteView = [[UIView alloc] init];
    self.remoteView.backgroundColor = [UIColor purpleColor];
    [self.remoteView addSubview:self.remoteRenderView];
}

#pragma mark - Local Media

-(void)setupLocalTracks {
    if ([self.channels[@"video"] isEqual: @YES]) {
        self.localVideoTrack = [self createVideoTrack];
    }
    if ([self.channels[@"audio" ] isEqual: @YES]) {
        self.localAudioTrack = [self createAudioTrack];
    }
}

-(RTCAudioTrack*)createAudioTrack {
    RTCMediaConstraints *audioConstrains = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:nil];
    RTCAudioSource *audioSource = [self.peerConnectionFactory audioSourceWithConstraints:audioConstrains];
    RTCAudioTrack *audioTrack = [self.peerConnectionFactory audioTrackWithSource:audioSource trackId:@"audio0"];
    
    return audioTrack;
}

-(RTCVideoTrack*)createVideoTrack {
    RTCVideoSource *videoSource = [self.peerConnectionFactory videoSource];
    
    
        self.videoCapturer = [[RTCCameraVideoCapturer new] initWithDelegate:videoSource];
    RTCVideoTrack *videoTrack = [self.peerConnectionFactory videoTrackWithSource:videoSource trackId:@"video0"];
    return videoTrack;
}

-(void)startCaptureLocalVideoWithCamPosition:(AVCaptureDevicePosition)cameraPosition videoWidth:(NSInteger)videoWidth videoHeight:(NSInteger)videoHeight videoFPS:(NSInteger)videoFps {
    
    if ([self.videoCapturer isKindOfClass:[RTCCameraVideoCapturer class]]) {
        RTCCameraVideoCapturer *capturer = (RTCCameraVideoCapturer *)self.videoCapturer;
        AVCaptureDevice *targetDevice;
        AVCaptureDeviceFormat *targetFormat;
        
        //find target device
        NSArray *devices = [RTCCameraVideoCapturer captureDevices];
        for (AVCaptureDevice *device in devices) {
            if (device.position == cameraPosition)
                targetDevice = device;
        }
        
        //find target format
        NSArray * formats = [RTCCameraVideoCapturer supportedFormatsForDevice:targetDevice];
        for (AVCaptureDeviceFormat *format in formats) {
            for (AVFrameRateRange *i in format.videoSupportedFrameRateRanges) {
                CMFormatDescriptionRef description = format.formatDescription;
                CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(description);
                
                if (dimensions.width == videoWidth && dimensions.height == videoHeight) {
                    targetFormat = format;
                }
                else if (dimensions.width == videoWidth){
                    targetFormat = format;
                }
            }
        }
        
        [capturer startCaptureWithDevice:targetDevice format:targetFormat fps:videoFps];
    }
    if ([self.videoCapturer isKindOfClass:[RTCFileVideoCapturer class]]) {
        //        RTCFileVideoCapturer *capturer = videoCapturer;
        NSLog(@"setup local file video capturer as no call");
        
        //shouls never come here
    }
}

#pragma mark - Local Data
-(RTCDataChannel*)setupDataChannel {
    RTCDataChannelConfiguration *dataChannelConfig = [RTCDataChannelConfiguration new];
    dataChannelConfig.channelId = 0;
    
    RTCDataChannel *datachannel = [self.peerConnection dataChannelForLabel:@"dataChannel" configuration:dataChannelConfig];
    return datachannel;
}

-(void)makeOffer:(void(^)(RTCSessionDescription*))onSuccess {
    [self.peerConnection offerForConstraints:[[RTCMediaConstraints new] initWithMandatoryConstraints:nil optionalConstraints:nil] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        if (error) {
            NSLog(@"error with make offer");
            return;
        }
        
        RTCSessionDescription*offerSDP = sdp;
        NSLog(@"make offer, created local sdp ");
        [self.peerConnection setLocalDescription:offerSDP completionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"error with set local offer sdp");
                return;
            }
            NSLog(@"succeed to set local offer SDP");
            onSuccess(offerSDP);
        }];
    }];
}

-(void)makeAnswer:(void(^)(RTCSessionDescription*))onCreateAnswer {
    [self.peerConnection answerForConstraints:[[RTCMediaConstraints new] initWithMandatoryConstraints:nil optionalConstraints:nil] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        if (error) {
            NSLog(@"failed to create local answer SDP");
            return;
        }
        NSLog(@"succeed to create local answer SDP");
        RTCSessionDescription *answerSDP = sdp;
        [self.peerConnection setLocalDescription:answerSDP completionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"failed to set local SDP");
                return;
            }
            NSLog(@"succeed to set local answer SDP");
            onCreateAnswer(answerSDP);
        }];
        
    }];
}

#pragma mark - Connection Events
-(void)onConnected {
    _isConnected = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.remoteRenderView setHidden:NO];
        [self.delegate didConnectWebRTC];
    });
}

-(void)onDisConnected {
    _isConnected = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"--- on dis connected ---");
        [self.peerConnection close];
        self.peerConnection = nil;
        [self.remoteRenderView setHidden:YES];
        self.dataChannel = nil;
        [self.delegate didDisconnectWebRTC];
    });
}

#pragma mark - PeerConnection Delegeates
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeSignalingState:(RTCSignalingState)stateChanged {
    NSString *state = @"";
    if (stateChanged == RTCSignalingStateStable) {
        state = @"stable";
    }
    
    if (stateChanged == RTCSignalingStateClosed) {
        state = @"closed";
    }
    
    NSLog(@"signaling state changed: %@", state);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceConnectionState:(RTCIceConnectionState)newState {
    switch (newState) {
        case RTCIceConnectionStateConnected:
            if (!self.isConnected) {
                [self onConnected];
            }
            break;
            
        case RTCIceConnectionStateCompleted:
            if (!self.isConnected) {
                [self onConnected];
            }
            break;
            
        default:
            if (self.isConnected) {
                [self onDisConnected];
            }
            break;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.delegate didIceConnectionStateChanged:newState];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream {
    
    NSLog(@"did add stream");
    self.remoteStream = stream;
    
    RTCVideoTrack *track = stream.videoTracks.firstObject;
    [track addRenderer:self.remoteRenderView];
    
    RTCAudioTrack *audioTrack = stream.audioTracks.firstObject;
    audioTrack.source.volume = 8;
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didGenerateIceCandidate:(RTCIceCandidate *)candidate {
    [self.delegate didGenerateCandidate:candidate];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream {
    NSLog(@"removed stream");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel {
    [self.delegate didOpenDataChannel];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates {
    
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceGatheringState:(RTCIceGatheringState)newState {
    
}

#pragma mark - RTCVideoView Delegate

- (void)videoView:(id<RTCVideoRenderer>)videoView didChangeVideoSize:(CGSize)size {
    BOOL isLandscape = NO;
    if(size.width < size.height)
        isLandscape = YES;
    
    RTCEAGLVideoView *renderView = [[RTCEAGLVideoView alloc] init];
    UIView *parentview = [[UIView alloc] init];
    
    if ([videoView isEqual:self.localRenderView]) {
        //local video size changed
        renderView = self.localRenderView;
        parentview = self.localView;
    }
    
    if ([videoView isEqual:self.remoteRenderView]) {
        //remote video size changed
        renderView = self.remoteRenderView;
        parentview = self.remoteView;
    }
    
    RTCEAGLVideoView* renderView1 = [[RTCEAGLVideoView alloc] init];
    UIView* parentview1 = [[UIView alloc] init];
    renderView1 = renderView;
    parentview1 = parentview;
    
    if (isLandscape) {
        CGFloat ratio = parentview1.frame.size.height / size.height;
        renderView1.frame = CGRectMake(0, 0, size.width * ratio, parentview1.frame.size.height);
        [renderView1 setCenter:CGPointMake(parentview1.frame.size.width/2, renderView1.center.y)];
    }
    else {
        CGFloat ratio = parentview1.frame.size.width / size.width;
        renderView1.frame = CGRectMake(0, 0, parentview1.frame.size.width, size.height * ratio);
        [renderView1 setCenter:CGPointMake(renderView1.center.x, parentview1.frame.size.height/2)];
    }
}

#pragma mark - RTCDataChannelDelegate

- (void)dataChannel:(RTCDataChannel *)dataChannel
didReceiveMessageWithBuffer:(RTCDataBuffer *)buffer {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([buffer isBinary]) {
            [self.delegate didReceiveData:buffer.data];
        }
        else {
            [self.delegate didReceiveMessage:[[NSString alloc] initWithData:buffer.data encoding:NSUTF8StringEncoding]];
        }
    });
}

- (void)dataChannelDidChangeState:(RTCDataChannel *)dataChannel {
    NSLog(@"data channel changed state");
}
@end
