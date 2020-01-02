//
//  WebRTCClient.h
//  SDWebRTC
//
//  Created by Sana Desai on 2019-12-29.
//  Copyright © 2019 Sana Desai. All rights reserved.
//

#import <Foundation/Foundation.h>

@import WebRTC;

NS_ASSUME_NONNULL_BEGIN

@protocol WebRTCClientDelegate <NSObject>

-(void)didGenerateCandidate:(RTCIceCandidate*)iceCandidate;
-(void)didIceConnectionStateChanged:(RTCIceConnectionState)iceConnectionState;
-(void)didOpenDataChannel;
-(void)didReceiveData:(NSData*)data;
-(void)didReceiveMessage:(NSString *)message;
-(void)didConnectWebRTC;
-(void)didDisconnectWebRTC;

@end

@interface WebRTCClient : NSObject < RTCPeerConnectionDelegate, RTCVideoViewDelegate, RTCDataChannelDelegate >

@property(nonatomic, assign)BOOL customFrameCapturer, isConnected;
@property(nonatomic, strong)RTCPeerConnectionFactory *peerConnectionFactory;
@property(nonatomic, strong)RTCPeerConnection *peerConnection;
@property(nonatomic, strong)RTCVideoCapturer *videoCapturer;
@property(nonatomic, retain)RTCVideoTrack *localVideoTrack;
@property(nonatomic, retain)RTCAudioTrack *localAudioTrack;
@property(nonatomic, retain)RTCEAGLVideoView *localRenderView;
@property(nonatomic, retain)UIView *localView, *remoteView;
@property(nonatomic, retain)RTCEAGLVideoView *remoteRenderView;
@property(nonatomic, retain)RTCMediaStream *remoteStream;
@property(nonatomic, retain)RTCDataChannel *dataChannel;
@property(nonatomic, strong)NSMutableDictionary *channels;


@property(nonatomic, weak) id<WebRTCClientDelegate> delegate;

-(UIView *)localVideoView;
-(UIView *)remoteVideoView;
-(void)setupWithVideo:(BOOL)videoTrack Audio:(BOOL)audioTrack dataChannel:(BOOL)dataChannel;
-(void)setupRemoteViewFrame:(CGRect)frame;
-(void)setupLocalViewFrame:(CGRect)frame;
-(void)connect:(void (^)(RTCSessionDescription*))onSuccess;
-(void)makeOffer:(void(^)(RTCSessionDescription*))onSuccess;
-(void)disconnect;

-(void)receiveAnswer:(RTCSessionDescription*)answerSDP;
-(void)receiveCandidate:(RTCIceCandidate*)candidate;
-(void)receiveOffer:(RTCSessionDescription*)offerSDP onCreateAnswer:(void(^)(RTCSessionDescription*))onCreateAnswer;

@end

NS_ASSUME_NONNULL_END
