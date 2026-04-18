//
//  MicUplinkManager.m
//  Moonlight
//

#import "MicUplinkManager.h"
#import "StreamConfiguration.h"
#import "HttpManager.h"
#import "HttpRequest.h"
#import "HttpResponse.h"
#import "Utils.h"

#import <AVFoundation/AVFoundation.h>

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <sys/socket.h>
#include <unistd.h>

#include "opus.h"

#define MIC_UPLINK_PAYLOAD_TYPE_OPUS 1
#define MIC_UPLINK_SAMPLE_RATE 48000
#define MIC_UPLINK_CHANNELS 1
#define MIC_UPLINK_FRAME_MS 20
#define MIC_UPLINK_FRAME_SAMPLES 960
#define MIC_UPLINK_MAX_OPUS_PACKET 4000

@interface MicUplinkSessionInfo : NSObject
@property (nonatomic) uint32_t sessionId;
@property (nonatomic) uint16_t port;
@property (nonatomic, strong) NSData *token;
@end

@implementation MicUplinkSessionInfo
@end

@implementation MicUplinkManager {
    StreamConfiguration *_config;
    dispatch_queue_t _queue;
    AVAudioEngine *_audioEngine;
    AVAudioConverter *_audioConverter;
    AVAudioFormat *_targetFormat;
    NSMutableData *_pcmAccumulator;
    OpusEncoder *_opusEncoder;
    int _socketFd;
    uint32_t _sequence;
    uint32_t _timestamp;
    uint32_t _sessionId;
    uint8_t _token[16];
    BOOL _running;
    BOOL _starting;
}

- (instancetype)initWithStreamConfig:(StreamConfiguration *)config {
    self = [super init];
    if (self) {
        _config = config;
        _queue = dispatch_queue_create("cn.axi.moonlight.mic-uplink", DISPATCH_QUEUE_SERIAL);
        _socketFd = -1;
    }
    return self;
}

- (BOOL)isRunning {
    @synchronized (self) {
        return _running;
    }
}

- (void)startWithCompletion:(MicUplinkStartCompletion)completion {
    @synchronized (self) {
        if (_running) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES, nil);
                });
            }
            return;
        }

        if (_starting) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, NSLocalizedString(@"stream.menu.microphone.starting", nil));
                });
            }
            return;
        }

        _starting = YES;
    }

    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession requestRecordPermission:^(BOOL granted) {
        if (!granted) {
            [self finishStartWithSuccess:NO message:NSLocalizedString(@"stream.menu.microphone.permission_denied", nil) completion:completion];
            return;
        }

        dispatch_async(self->_queue, ^{
            NSError *error = nil;
            MicUplinkSessionInfo *info = [self requestMicUplinkSessionWithError:&error];
            if (info == nil) {
                [self finishStartWithSuccess:NO
                                     message:error.localizedDescription ?: NSLocalizedString(@"stream.menu.microphone.unavailable", nil)
                                  completion:completion];
                return;
            }

            if (![self startUdpWithSessionInfo:info error:&error] ||
                ![self startAudioCaptureWithSessionInfo:info error:&error]) {
                [self stopInternal];
                [self finishStartWithSuccess:NO
                                     message:error.localizedDescription ?: NSLocalizedString(@"stream.menu.microphone.unavailable", nil)
                                  completion:completion];
                return;
            }

            @synchronized (self) {
                self->_running = YES;
                self->_starting = NO;
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES, nil);
                });
            }
        });
    }];
}

- (void)stop {
    dispatch_async(_queue, ^{
        [self stopInternal];
    });
}

- (void)finishStartWithSuccess:(BOOL)success message:(NSString *)message completion:(MicUplinkStartCompletion)completion {
    @synchronized (self) {
        _starting = NO;
        _running = success;
    }

    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, message);
        });
    }
}

- (MicUplinkSessionInfo *)requestMicUplinkSessionWithError:(NSError **)error {
    HttpManager *httpManager = [[HttpManager alloc] initWithAddress:_config.host
                                                          httpsPort:_config.httpsPort
                                                         serverCert:_config.serverCert];
    HttpResponse *response = [[HttpResponse alloc] init];
    [httpManager executeRequestSynchronously:[HttpRequest requestForResponse:response
                                                              withUrlRequest:[httpManager newMicUplinkRequest]]];

    NSInteger enabled = 0;
    if (![response isStatusOk] ||
        ![response getIntTag:@"axiMicEnabled" value:&enabled] ||
        enabled != 1) {
        NSString *message = response.statusMessage ?: NSLocalizedString(@"stream.menu.microphone.unavailable", nil);
        if (error) {
            *error = [NSError errorWithDomain:@"MicUplink"
                                         code:response.statusCode
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return nil;
    }

    NSInteger port = 0;
    NSInteger sessionId = 0;
    NSString *codec = [[response getStringTag:@"axiMicCodec"] lowercaseString];
    NSString *tokenString = [response getStringTag:@"axiMicToken"];
    NSInteger sampleRate = MIC_UPLINK_SAMPLE_RATE;
    NSInteger channels = MIC_UPLINK_CHANNELS;
    NSInteger frameMs = MIC_UPLINK_FRAME_MS;
    uint8_t tokenBytes[16];
    [response getIntTag:@"axiMicSampleRate" value:&sampleRate];
    [response getIntTag:@"axiMicChannels" value:&channels];
    [response getIntTag:@"axiMicFrameMs" value:&frameMs];

    MicUplinkSessionInfo *info = [[MicUplinkSessionInfo alloc] init];
    if (![response getIntTag:@"axiMicPort" value:&port] ||
        ![response getIntTag:@"axiMicSessionId" value:&sessionId] ||
        port <= 0 || port > UINT16_MAX ||
        sessionId < 0 ||
        ![codec isEqualToString:@"opus"] ||
        sampleRate != MIC_UPLINK_SAMPLE_RATE ||
        channels != MIC_UPLINK_CHANNELS ||
        frameMs != MIC_UPLINK_FRAME_MS ||
        ![self decodeHexToken:tokenString into:tokenBytes]) {
        if (error) {
            *error = [NSError errorWithDomain:@"MicUplink"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"stream.menu.microphone.invalid_session", nil)}];
        }
        return nil;
    }

    info.port = (uint16_t)port;
    info.sessionId = (uint32_t)sessionId;
    info.token = [NSData dataWithBytes:tokenBytes length:sizeof(tokenBytes)];
    return info;
}

- (BOOL)decodeHexToken:(NSString *)tokenString into:(uint8_t *)token {
    if (tokenString.length != 32) {
        return NO;
    }

    for (NSUInteger i = 0; i < 16; i++) {
        unsigned int byte = 0;
        NSString *part = [tokenString substringWithRange:NSMakeRange(i * 2, 2)];
        NSScanner *scanner = [NSScanner scannerWithString:part];
        if (![scanner scanHexInt:&byte] || byte > 0xFF) {
            return NO;
        }
        token[i] = (uint8_t)byte;
    }

    return YES;
}

- (BOOL)startUdpWithSessionInfo:(MicUplinkSessionInfo *)info error:(NSError **)error {
    NSString *address = [Utils addressPortStringToAddress:_config.host];
    NSString *portString = [NSString stringWithFormat:@"%u", info.port];

    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_DGRAM;

    struct addrinfo *result = NULL;
    int ret = getaddrinfo(address.UTF8String, portString.UTF8String, &hints, &result);
    if (ret != 0 || result == NULL) {
        if (error) {
            *error = [NSError errorWithDomain:@"MicUplink"
                                         code:ret
                                     userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"stream.menu.microphone.network_failed", nil)}];
        }
        return NO;
    }

    int socketFd = -1;
    for (struct addrinfo *ai = result; ai != NULL; ai = ai->ai_next) {
        socketFd = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
        if (socketFd < 0) {
            continue;
        }

        if (connect(socketFd, ai->ai_addr, ai->ai_addrlen) == 0) {
            break;
        }

        close(socketFd);
        socketFd = -1;
    }

    freeaddrinfo(result);

    if (socketFd < 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"MicUplink"
                                         code:errno
                                     userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"stream.menu.microphone.network_failed", nil)}];
        }
        return NO;
    }

    int flags = fcntl(socketFd, F_GETFL, 0);
    if (flags >= 0) {
        fcntl(socketFd, F_SETFL, flags | O_NONBLOCK);
    }

    _socketFd = socketFd;
    _sessionId = info.sessionId;
    memcpy(_token, info.token.bytes, MIN(info.token.length, sizeof(_token)));
    _sequence = 0;
    _timestamp = 0;
    return YES;
}

- (BOOL)startAudioCaptureWithSessionInfo:(MicUplinkSessionInfo *)info error:(NSError **)error {
    (void)info;

    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                       withOptions:(AVAudioSessionCategoryOptionMixWithOthers |
                                    AVAudioSessionCategoryOptionAllowBluetoothHFP |
                                    AVAudioSessionCategoryOptionDefaultToSpeaker)
                             error:error]) {
        return NO;
    }

    if (![audioSession setMode:AVAudioSessionModeDefault error:error] ||
        ![audioSession setPreferredSampleRate:MIC_UPLINK_SAMPLE_RATE error:error] ||
        ![audioSession setActive:YES error:error]) {
        return NO;
    }

    int opusError = OPUS_OK;
    _opusEncoder = opus_encoder_create(MIC_UPLINK_SAMPLE_RATE, MIC_UPLINK_CHANNELS, OPUS_APPLICATION_VOIP, &opusError);
    if (_opusEncoder == NULL || opusError != OPUS_OK) {
        if (error) {
            *error = [NSError errorWithDomain:@"MicUplink"
                                         code:opusError
                                     userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"stream.menu.microphone.encoder_failed", nil)}];
        }
        return NO;
    }
    opus_encoder_ctl(_opusEncoder, OPUS_SET_BITRATE(24000));
    opus_encoder_ctl(_opusEncoder, OPUS_SET_COMPLEXITY(5));
    opus_encoder_ctl(_opusEncoder, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));

    _audioEngine = [[AVAudioEngine alloc] init];
    AVAudioInputNode *inputNode = _audioEngine.inputNode;
    AVAudioFormat *inputFormat = [inputNode outputFormatForBus:0];
    _targetFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                     sampleRate:MIC_UPLINK_SAMPLE_RATE
                                                       channels:MIC_UPLINK_CHANNELS
                                                    interleaved:NO];
    _audioConverter = [[AVAudioConverter alloc] initFromFormat:inputFormat toFormat:_targetFormat];
    _pcmAccumulator = [NSMutableData dataWithCapacity:MIC_UPLINK_FRAME_SAMPLES * sizeof(int16_t) * 4];

    __weak MicUplinkManager *weakSelf = self;
    AVAudioFrameCount tapBufferSize = MAX(1, (AVAudioFrameCount)(inputFormat.sampleRate * MIC_UPLINK_FRAME_MS / 1000.0));
    [inputNode installTapOnBus:0 bufferSize:tapBufferSize format:inputFormat block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        (void)when;
        MicUplinkManager *strongSelf = weakSelf;
        AVAudioPCMBuffer *copiedBuffer = [strongSelf copyPCMBuffer:buffer];
        if (strongSelf == nil || copiedBuffer == nil) {
            return;
        }

        dispatch_async(strongSelf->_queue, ^{
            [strongSelf processInputBuffer:copiedBuffer];
        });
    }];

    if (![_audioEngine startAndReturnError:error]) {
        [inputNode removeTapOnBus:0];
        return NO;
    }

    return YES;
}

- (AVAudioPCMBuffer *)copyPCMBuffer:(AVAudioPCMBuffer *)buffer {
    AVAudioPCMBuffer *copiedBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:buffer.format
                                                                   frameCapacity:buffer.frameLength];
    if (copiedBuffer == nil) {
        return nil;
    }

    copiedBuffer.frameLength = buffer.frameLength;
    const AudioBufferList *sourceList = buffer.audioBufferList;
    AudioBufferList *destinationList = copiedBuffer.mutableAudioBufferList;
    UInt32 bufferCount = MIN(sourceList->mNumberBuffers, destinationList->mNumberBuffers);
    for (UInt32 i = 0; i < bufferCount; i++) {
        UInt32 byteCount = MIN(sourceList->mBuffers[i].mDataByteSize, destinationList->mBuffers[i].mDataByteSize);
        if (sourceList->mBuffers[i].mData != NULL && destinationList->mBuffers[i].mData != NULL && byteCount > 0) {
            memcpy(destinationList->mBuffers[i].mData, sourceList->mBuffers[i].mData, byteCount);
            destinationList->mBuffers[i].mDataByteSize = byteCount;
        }
    }

    return copiedBuffer;
}

- (void)processInputBuffer:(AVAudioPCMBuffer *)buffer {
    @synchronized (self) {
        if (!_running && !_starting) {
            return;
        }
    }

    if (_audioConverter == nil || _targetFormat == nil || _opusEncoder == NULL || _socketFd < 0) {
        return;
    }

    AVAudioFrameCount capacity = (AVAudioFrameCount)ceil((double)buffer.frameLength * MIC_UPLINK_SAMPLE_RATE / buffer.format.sampleRate) + 64;
    AVAudioPCMBuffer *convertedBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:_targetFormat frameCapacity:capacity];
    __block BOOL didProvideInput = NO;
    NSError *error = nil;
    AVAudioConverterInputBlock inputBlock = ^AVAudioBuffer * _Nullable(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus *outStatus) {
        (void)inNumberOfPackets;
        if (didProvideInput) {
            *outStatus = AVAudioConverterInputStatus_NoDataNow;
            return nil;
        }
        didProvideInput = YES;
        *outStatus = AVAudioConverterInputStatus_HaveData;
        return buffer;
    };

    [_audioConverter convertToBuffer:convertedBuffer error:&error withInputFromBlock:inputBlock];
    if (error != nil || convertedBuffer.frameLength == 0 || convertedBuffer.int16ChannelData == NULL) {
        return;
    }

    const int16_t *samples = convertedBuffer.int16ChannelData[0];
    [_pcmAccumulator appendBytes:samples length:convertedBuffer.frameLength * sizeof(int16_t)];

    NSUInteger frameBytes = MIC_UPLINK_FRAME_SAMPLES * sizeof(int16_t);
    while (_pcmAccumulator.length >= frameBytes) {
        const opus_int16 *pcm = (const opus_int16 *)_pcmAccumulator.bytes;
        [self encodeAndSendFrame:pcm];
        [_pcmAccumulator replaceBytesInRange:NSMakeRange(0, frameBytes) withBytes:NULL length:0];
    }
}

- (void)encodeAndSendFrame:(const opus_int16 *)pcm {
    uint8_t payload[MIC_UPLINK_MAX_OPUS_PACKET];
    opus_int32 payloadSize = opus_encode(_opusEncoder,
                                         pcm,
                                         MIC_UPLINK_FRAME_SAMPLES,
                                         payload,
                                         sizeof(payload));
    if (payloadSize <= 0) {
        return;
    }

    uint8_t packet[32 + MIC_UPLINK_MAX_OPUS_PACKET];
    uint32_t sessionId = htonl(_sessionId);
    uint32_t sequence = htonl(_sequence++);
    uint32_t timestamp = htonl(_timestamp);
    uint16_t payloadSizeBe = htons((uint16_t)payloadSize);
    _timestamp += MIC_UPLINK_FRAME_SAMPLES;

    memcpy(packet, &sessionId, sizeof(sessionId));
    memcpy(packet + 4, &sequence, sizeof(sequence));
    memcpy(packet + 8, &timestamp, sizeof(timestamp));
    memcpy(packet + 12, _token, sizeof(_token));
    packet[28] = MIC_UPLINK_PAYLOAD_TYPE_OPUS;
    packet[29] = 0;
    memcpy(packet + 30, &payloadSizeBe, sizeof(payloadSizeBe));
    memcpy(packet + 32, payload, (size_t)payloadSize);

    ssize_t ret = send(_socketFd, packet, 32 + (size_t)payloadSize, 0);
    if (ret < 0 && errno != EWOULDBLOCK && errno != EAGAIN) {
        Log(LOG_W, @"Mic uplink UDP send failed: %d", errno);
    }
}

- (void)stopInternal {
    @synchronized (self) {
        _running = NO;
        _starting = NO;
    }

    if (_audioEngine != nil) {
        [_audioEngine.inputNode removeTapOnBus:0];
        [_audioEngine stop];
        _audioEngine = nil;
    }

    _audioConverter = nil;
    _targetFormat = nil;
    _pcmAccumulator = nil;

    if (_opusEncoder != NULL) {
        opus_encoder_destroy(_opusEncoder);
        _opusEncoder = NULL;
    }

    if (_socketFd >= 0) {
        close(_socketFd);
        _socketFd = -1;
    }

    _sequence = 0;
    _timestamp = 0;
    _sessionId = 0;
    memset(_token, 0, sizeof(_token));

    NSError *audioError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                     withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                           error:&audioError];
    if (audioError != nil) {
        Log(LOG_W, @"Failed to restore audio session after mic uplink: %@", audioError);
    }
}

- (void)dealloc {
    [self stopInternal];
}

@end
