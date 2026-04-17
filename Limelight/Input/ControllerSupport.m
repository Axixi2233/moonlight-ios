//
//  ControllerSupport.m
//  Moonlight
//
//  Created by Cameron Gutman on 10/20/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "ControllerSupport.h"
#import "Controller.h"

#import "DataManager.h"
#include "Limelight.h"
#include <float.h>
#include <limits.h>
#include <math.h>

@import GameController;
@import AudioToolbox;

//设备陀螺仪
#if !TARGET_OS_TV
    @import CoreMotion;
#endif

static const double MOUSE_SPEED_DIVISOR = 1.0;

static float AdjustMouseDeltaForLowSpeed(float delta) {
    float magnitude = fabsf(delta);
    if (magnitude < 1.0f) {
        return delta * 1.35f;
    }
    if (magnitude < 2.0f) {
        return delta * 1.15f;
    }
    return delta;
}

static short ConsumeAccumulatedMouseDelta(float *accumulatedDelta) {
    if (accumulatedDelta == NULL || fabsf(*accumulatedDelta) < 0.5f) {
        return 0;
    }

    float roundedDelta = *accumulatedDelta > 0.0f ? floorf(*accumulatedDelta + 0.5f) : ceilf(*accumulatedDelta - 0.5f);
    roundedDelta = fmaxf((float)SHRT_MIN, fminf((float)SHRT_MAX, roundedDelta));

    short emittedDelta = (short)roundedDelta;
    *accumulatedDelta -= emittedDelta;
    return emittedDelta;
}

static float MouseSensitivityScaleForPercentage(NSInteger relativeMouseSensitivity) {
    return MAX(0.5f, MIN((float)relativeMouseSensitivity / 100.0f, 3.0f));
}

static const NSTimeInterval kStartButtonHoldDurationForGameMenu = 0.6;

typedef struct {
    float smoothedEnergy;
    float smoothedVoice;
    float smoothedTransient;
    float smoothedDeviceAmplitude;
    float smoothedLowMotorAmplitude;
    float smoothedHighMotorAmplitude;
    float previousMonoSample;
} audio_haptics_state_t;

static float ClampUnitFloat(float value) {
    return fmaxf(0.0f, fminf(1.0f, value));
}

static uint16_t AudioHapticsAmplitudeFromUnitFloat(float value) {
    return (uint16_t)lrintf(ClampUnitFloat(value) * 65535.0f);
}

static float VoiceFilterCutoffForSelection(NSInteger selection) {
    switch (selection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
            return 900.0f;
        case StreamAudioHapticsVoiceFilterSelectionMedium:
            return 1300.0f;
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return 1800.0f;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return 0.0f;
    }
}

static float VoiceFilterStrengthForSelection(NSInteger selection) {
    switch (selection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
            return 0.22f;
        case StreamAudioHapticsVoiceFilterSelectionMedium:
            return 0.46f;
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return 0.72f;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return 0.0f;
    }
}

static float VoiceFilterBlendForSelection(NSInteger selection) {
    switch (selection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
            return 0.30f;
        case StreamAudioHapticsVoiceFilterSelectionMedium:
            return 0.58f;
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return 0.85f;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return 0.0f;
    }
}

static float ControllerVoiceFilterBaseMultiplier(NSInteger selection) {
    switch (selection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
            return 0.98f;
        case StreamAudioHapticsVoiceFilterSelectionMedium:
            return 0.58f;
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return 0.14f;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return 1.0f;
    }
}

static float ControllerVoiceFilterTransientBoost(NSInteger selection) {
    switch (selection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
            return 1.00f;
        case StreamAudioHapticsVoiceFilterSelectionMedium:
            return 1.34f;
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return 1.95f;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return 1.0f;
    }
}

static float ControllerLowMotorBaseMix(NSInteger selection) {
    switch (selection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
            return 2.90f;
        case StreamAudioHapticsVoiceFilterSelectionMedium:
            return 1.95f;
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return 1.05f;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return 2.70f;
    }
}

static float ControllerHighMotorTransientMix(NSInteger selection) {
    switch (selection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
            return 2.00f;
        case StreamAudioHapticsVoiceFilterSelectionMedium:
            return 2.45f;
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return 2.55f;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return 2.15f;
    }
}

static float ControllerHighMotorBaseBleed(NSInteger selection) {
    switch (selection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
            return 0.12f;
        case StreamAudioHapticsVoiceFilterSelectionMedium:
            return 0.05f;
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return 0.02f;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return 0.10f;
    }
}

static float ControllerLowMotorReleaseAlpha(NSInteger selection) {
    switch (selection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
            return 0.18f;
        case StreamAudioHapticsVoiceFilterSelectionMedium:
            return 0.24f;
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return 0.38f;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return 0.14f;
    }
}

static float ControllerHighMotorReleaseAlpha(NSInteger selection) {
    switch (selection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
            return 0.20f;
        case StreamAudioHapticsVoiceFilterSelectionMedium:
            return 0.26f;
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return 0.42f;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return 0.16f;
    }
}

static NSInteger NormalizedAudioHapticsOutputTargetValue(NSInteger outputTarget) {
    switch (outputTarget) {
        case StreamAudioHapticsOutputTargetController:
            return StreamAudioHapticsOutputTargetController;
        case StreamAudioHapticsOutputTargetDevice:
        default:
            return StreamAudioHapticsOutputTargetDevice;
    }
}

static NSInteger NormalizedAudioHapticsStrengthValue(NSInteger strength) {
    return MAX(25, MIN(strength, 200));
}

static NSInteger NormalizedAudioHapticsVoiceFilterSelectionValue(NSInteger selection) {
    switch (selection) {
        case StreamAudioHapticsVoiceFilterSelectionLow:
        case StreamAudioHapticsVoiceFilterSelectionMedium:
        case StreamAudioHapticsVoiceFilterSelectionHigh:
            return selection;
        case StreamAudioHapticsVoiceFilterSelectionOff:
        default:
            return StreamAudioHapticsVoiceFilterSelectionOff;
    }
}

static float OnePoleSmoothingAlpha(float cutoffHz, int sampleRate) {
    if (cutoffHz <= 0.0f || sampleRate <= 0) {
        return 0.0f;
    }
    float dt = 1.0f / (float)sampleRate;
    float rc = 1.0f / (2.0f * (float)M_PI * cutoffHz);
    return dt / (rc + dt);
}

static float ApplyAttackReleaseSmoothing(float current, float target, float attackAlpha, float releaseAlpha) {
    float alpha = target > current ? attackAlpha : releaseAlpha;
    return current + ((target - current) * alpha);
}

@implementation ControllerSupport {
    id _controllerConnectObserver;
    id _controllerDisconnectObserver;
    id _mouseConnectObserver;
    id _mouseDisconnectObserver;
    id _keyboardConnectObserver;
    id _keyboardDisconnectObserver;
    
    NSLock *_controllerStreamLock;
    NSMutableDictionary *_controllers;
    id<ControllerSupportDelegate> _delegate;
    
    float accumulatedDeltaX;
    float accumulatedDeltaY;
    float accumulatedScrollX;
    float accumulatedScrollY;
    
    Controller *_oscController;
    
#define EMULATING_SELECT     0x1
#define EMULATING_SPECIAL    0x2
    
    bool _oscEnabled;
    char _controllerNumbers;
    bool _multiController;
    bool _swapABXYButtons;
    
    int _motionMode;//陀螺仪模式
    
    NSInteger _rumbleMode;
    BOOL _remoteMouseMode;
    BOOL _mouseInputSuppressed;
    float _relativeMouseSensitivityScale;
    BOOL _longPressStartForGameMenuEnabled;
    BOOL _audioHapticsEnabled;
    NSInteger _audioHapticsOutputTarget;
    float _audioHapticsStrengthScale;
    NSInteger _audioHapticsVoiceFilterSelection;
    BOOL _audioHapticsKeepControllerRumble;
    HapticContext *_audioDeviceHaptics;
    audio_haptics_state_t _audioDeviceState;
    audio_haptics_state_t _audioControllerState;
}

// UPDATE_BUTTON_FLAG(controller, flag, pressed)
#define UPDATE_BUTTON_FLAG(controller, x, y) \
((y) ? [self setButtonFlag:controller flags:x] : [self clearButtonFlag:controller flags:x])

#define MAX_MAGNITUDE(x, y) (abs(x) > abs(y) ? (x) : (y))

#if !TARGET_OS_TV
-(void) setMouseInputSuppressed:(BOOL)suppressed {
    _mouseInputSuppressed = suppressed;

    if (suppressed) {
        accumulatedDeltaX = 0;
        accumulatedDeltaY = 0;
        accumulatedScrollX = 0;
        accumulatedScrollY = 0;
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_MIDDLE);
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_X1);
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_X2);
    }
}

- (void)startDeviceMotionUpdatesForController:(Controller *)controller reportRateHz:(uint16_t)reportRateHz {
    if (controller.motionManager == nil) {
        controller.motionManager = [[CMMotionManager alloc] init];
    }

    if (reportRateHz > 0) {
        controller.motionManager.deviceMotionUpdateInterval = 1.0 / reportRateHz;
    }

    if (!controller.motionManager.isDeviceMotionActive) {
        [controller.motionManager startDeviceMotionUpdates];
    }
}

- (void)stopDeviceMotionUpdatesIfIdleForController:(Controller *)controller {
    if (controller.motionManager == nil) {
        return;
    }

    if (controller.accelTimer == nil && controller.gyroTimer == nil && controller.motionManager.isDeviceMotionActive) {
        [controller.motionManager stopDeviceMotionUpdates];
    }
}
#else
-(void) setMouseInputSuppressed:(BOOL)suppressed {
    (void)suppressed;
}
#endif

-(void) rumble:(unsigned short)controllerNumber lowFreqMotor:(unsigned short)lowFreqMotor highFreqMotor:(unsigned short)highFreqMotor
{
    if (_rumbleMode == StreamRumbleModeSelectionDisabled) {
        return;
    }

    Controller* controller = [_controllers objectForKey:[NSNumber numberWithInteger:controllerNumber]];
    if (controller == nil && controllerNumber == 0 && _oscEnabled) {
        // TODO: Rumble emulation for OSC
        if (_rumbleMode == StreamRumbleModeSelectionDevice) {
            controller = _oscController;
            [self initializeControllerHaptics:controller];
        }
    }
    if (controller == nil) {
        // No connected controller for this player
        return;
    }
    
    controller.gameLowFreqMotorAmplitude = lowFreqMotor;
    controller.gameHighFreqMotorAmplitude = highFreqMotor;
    [self applyCombinedRumbleForController:controller];
}

-(void) rumbleTriggers:(uint16_t)controllerNumber leftTrigger:(uint16_t)leftTrigger rightTrigger:(uint16_t)rightTrigger
{
    if (_rumbleMode == StreamRumbleModeSelectionDisabled) {
        return;
    }

    Controller* controller = [_controllers objectForKey:[NSNumber numberWithInteger:controllerNumber]];
    if (controller == nil && controllerNumber == 0 && _oscEnabled) {
        // TODO: Trigger rumble emulation for OSC
    }
    if (controller == nil) {
        // No connected controller for this player
        return;
    }
    
    controller.gameLeftTriggerMotorAmplitude = leftTrigger;
    controller.gameRightTriggerMotorAmplitude = rightTrigger;
    [self applyCombinedRumbleForController:controller];
}

- (BOOL)isAudioHapticsDrivingControllerRumble {
    return _audioHapticsEnabled && _audioHapticsOutputTarget == StreamAudioHapticsOutputTargetController;
}

- (BOOL)shouldUseDedicatedAudioControllerHaptics {
    return _audioHapticsEnabled &&
           _audioHapticsOutputTarget == StreamAudioHapticsOutputTargetController &&
           _rumbleMode != StreamRumbleModeSelectionController;
}

- (void)ensureAudioDeviceHapticsIfNeeded {
    if (!_audioHapticsEnabled || _audioHapticsOutputTarget != StreamAudioHapticsOutputTargetDevice || _audioDeviceHaptics != nil) {
        return;
    }
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        _audioDeviceHaptics = [HapticContext createForcedDeviceContext];
    }
}

- (void)applyCombinedRumbleForController:(Controller *)controller {
    if (controller == nil) {
        return;
    }

    BOOL audioOnController = [self isAudioHapticsDrivingControllerRumble];
    BOOL keepGameControllerRumble = !audioOnController || _audioHapticsKeepControllerRumble;

    if (audioOnController && _rumbleMode != StreamRumbleModeSelectionController) {
        [controller.lowFreqMotor setMotorAmplitude:controller.gameLowFreqMotorAmplitude];
        [controller.highFreqMotor setMotorAmplitude:controller.gameHighFreqMotorAmplitude];
        [controller.leftTriggerMotor setMotorAmplitude:controller.gameLeftTriggerMotorAmplitude];
        [controller.rightTriggerMotor setMotorAmplitude:controller.gameRightTriggerMotorAmplitude];
        [controller.audioLowFreqMotor setMotorAmplitude:controller.audioLowFreqMotorAmplitude];
        [controller.audioHighFreqMotor setMotorAmplitude:controller.audioHighFreqMotorAmplitude];
        return;
    }

    uint16_t lowAmplitude = controller.audioLowFreqMotorAmplitude;
    uint16_t highAmplitude = controller.audioHighFreqMotorAmplitude;
    if (keepGameControllerRumble) {
        lowAmplitude = MAX(lowAmplitude, controller.gameLowFreqMotorAmplitude);
        highAmplitude = MAX(highAmplitude, controller.gameHighFreqMotorAmplitude);
    }

    [controller.lowFreqMotor setMotorAmplitude:lowAmplitude];
    [controller.highFreqMotor setMotorAmplitude:highAmplitude];

    uint16_t leftTriggerAmplitude = keepGameControllerRumble ? controller.gameLeftTriggerMotorAmplitude : 0;
    uint16_t rightTriggerAmplitude = keepGameControllerRumble ? controller.gameRightTriggerMotorAmplitude : 0;
    [controller.leftTriggerMotor setMotorAmplitude:leftTriggerAmplitude];
    [controller.rightTriggerMotor setMotorAmplitude:rightTriggerAmplitude];
    [controller.audioLowFreqMotor setMotorAmplitude:0];
    [controller.audioHighFreqMotor setMotorAmplitude:0];
}

- (void)clearAudioDrivenRumbleState {
    _audioDeviceState = (audio_haptics_state_t){0};
    _audioControllerState = (audio_haptics_state_t){0};
    [_audioDeviceHaptics setMotorAmplitude:0];

    for (Controller *controller in [_controllers allValues]) {
        controller.audioLowFreqMotorAmplitude = 0;
        controller.audioHighFreqMotorAmplitude = 0;
        [self applyCombinedRumbleForController:controller];
    }
}

- (void)syncAudioHapticsResourcesForController:(Controller *)controller {
    if (controller == nil) {
        return;
    }

    if ([self shouldUseDedicatedAudioControllerHaptics]) {
        if (controller.audioLowFreqMotor == nil) {
            controller.audioLowFreqMotor = [HapticContext createForcedControllerLowFreqMotor:controller.gamepad];
        }
        if (controller.audioHighFreqMotor == nil) {
            controller.audioHighFreqMotor = [HapticContext createForcedControllerHighFreqMotor:controller.gamepad];
        }
        return;
    }

    [controller.audioLowFreqMotor cleanup];
    controller.audioLowFreqMotor = nil;
    [controller.audioHighFreqMotor cleanup];
    controller.audioHighFreqMotor = nil;
}

- (void)syncAudioHapticsResources {
    if (!_audioHapticsEnabled || _audioHapticsOutputTarget != StreamAudioHapticsOutputTargetDevice) {
        [_audioDeviceHaptics cleanup];
        _audioDeviceHaptics = nil;
    }

    for (Controller *controller in [_controllers allValues]) {
        [self syncAudioHapticsResourcesForController:controller];
    }
}

- (void)updateControllerAudioHapticsWithLowAmplitude:(uint16_t)lowAmplitude highAmplitude:(uint16_t)highAmplitude {
    for (Controller *controller in [_controllers allValues]) {
        controller.audioLowFreqMotorAmplitude = lowAmplitude;
        controller.audioHighFreqMotorAmplitude = highAmplitude;
        [self applyCombinedRumbleForController:controller];
    }
}

- (float)audioHapticsVoiceCutoffHz {
    return VoiceFilterCutoffForSelection(_audioHapticsVoiceFilterSelection);
}

- (void)accumulateAudioHapticsMetricsForSamples:(const short *)samples
                                     frameCount:(int)frameCount
                                   channelCount:(int)channelCount
                                     sampleRate:(int)sampleRate
                                          state:(audio_haptics_state_t *)state
                                      baseLevel:(float *)baseLevel
                                 transientLevel:(float *)transientLevel {
    if (samples == NULL || frameCount <= 0 || channelCount <= 0 || state == NULL || baseLevel == NULL || transientLevel == NULL) {
        if (baseLevel != NULL) {
            *baseLevel = 0.0f;
        }
        if (transientLevel != NULL) {
            *transientLevel = 0.0f;
        }
        return;
    }

    float energyAccumulator = 0.0f;
    float transientAccumulator = 0.0f;
    float lowAlpha = OnePoleSmoothingAlpha(180.0f, sampleRate);
    float voiceCutoffHz = [self audioHapticsVoiceCutoffHz];
    float voiceAlpha = OnePoleSmoothingAlpha(voiceCutoffHz, sampleRate);
    float voiceStrength = VoiceFilterStrengthForSelection(_audioHapticsVoiceFilterSelection);

    for (int frameIndex = 0; frameIndex < frameCount; frameIndex++) {
        float monoSample = 0.0f;
        for (int channelIndex = 0; channelIndex < channelCount; channelIndex++) {
            monoSample += samples[(frameIndex * channelCount) + channelIndex] / 32768.0f;
        }
        monoSample /= (float)channelCount;

        float absSample = fabsf(monoSample);
        energyAccumulator += absSample;
        transientAccumulator += fabsf(monoSample - state->previousMonoSample);
        state->previousMonoSample = monoSample;
    }

    float averageEnergy = energyAccumulator / (float)frameCount;
    float averageTransient = transientAccumulator / (float)frameCount;
    state->smoothedEnergy += (averageEnergy - state->smoothedEnergy) * lowAlpha;
    if (voiceAlpha > 0.0f) {
        state->smoothedVoice += (averageEnergy - state->smoothedVoice) * voiceAlpha;
    }
    else {
        state->smoothedVoice = 0.0f;
    }
    state->smoothedTransient += (averageTransient - state->smoothedTransient) * 0.18f;

    float filteredBase = state->smoothedEnergy;
    if (voiceStrength > 0.0f) {
        float fullyFilteredBase = fmaxf(0.0f, state->smoothedEnergy - (state->smoothedVoice * voiceStrength));
        float filterBlend = VoiceFilterBlendForSelection(_audioHapticsVoiceFilterSelection);
        filteredBase = state->smoothedEnergy + ((fullyFilteredBase - state->smoothedEnergy) * filterBlend);
    }

    *baseLevel = ClampUnitFloat(filteredBase);
    *transientLevel = ClampUnitFloat(fmaxf(0.0f, (state->smoothedTransient * 2.25f) - (*baseLevel * 0.30f)));
}

- (void)processAudioHapticsSamples:(const short *)samples
                         frameCount:(int)frameCount
                       channelCount:(int)channelCount
                         sampleRate:(int)sampleRate {
    if (!_audioHapticsEnabled || samples == NULL || frameCount <= 0 || channelCount <= 0 || sampleRate <= 0) {
        return;
    }

    if (_audioHapticsOutputTarget == StreamAudioHapticsOutputTargetDevice) {
        [self ensureAudioDeviceHapticsIfNeeded];
        if (_audioDeviceHaptics == nil) {
            return;
        }

        float baseLevel = 0.0f;
        float transientLevel = 0.0f;
        [self accumulateAudioHapticsMetricsForSamples:samples
                                           frameCount:frameCount
                                         channelCount:channelCount
                                           sampleRate:sampleRate
                                                state:&_audioDeviceState
                                            baseLevel:&baseLevel
                                       transientLevel:&transientLevel];

        float targetAmplitude = ClampUnitFloat(powf(ClampUnitFloat((baseLevel * 2.85f * _audioHapticsStrengthScale) + (transientLevel * 0.52f)), 0.68f));
        if (targetAmplitude < 0.008f) {
            targetAmplitude = 0.0f;
        }
        _audioDeviceState.smoothedDeviceAmplitude = ApplyAttackReleaseSmoothing(_audioDeviceState.smoothedDeviceAmplitude,
                                                                                targetAmplitude,
                                                                                0.48f,
                                                                                0.24f);
        if (_audioDeviceState.smoothedDeviceAmplitude < 0.0024f) {
            _audioDeviceState.smoothedDeviceAmplitude = 0.0f;
        }
        [_audioDeviceHaptics setMotorAmplitude:AudioHapticsAmplitudeFromUnitFloat(_audioDeviceState.smoothedDeviceAmplitude)];
        return;
    }

    float baseLevel = 0.0f;
    float transientLevel = 0.0f;
    [self accumulateAudioHapticsMetricsForSamples:samples
                                       frameCount:frameCount
                                     channelCount:channelCount
                                       sampleRate:sampleRate
                                            state:&_audioControllerState
                                        baseLevel:&baseLevel
                                   transientLevel:&transientLevel];

    float controllerBaseLevel = ClampUnitFloat(baseLevel * ControllerVoiceFilterBaseMultiplier(_audioHapticsVoiceFilterSelection));
    float controllerTransientLevel = ClampUnitFloat(transientLevel * ControllerVoiceFilterTransientBoost(_audioHapticsVoiceFilterSelection));
    if (_audioHapticsVoiceFilterSelection == StreamAudioHapticsVoiceFilterSelectionHigh) {
        controllerTransientLevel = ClampUnitFloat(controllerTransientLevel + (transientLevel * 0.32f));
    }

    float targetLowAmplitude = ClampUnitFloat(powf(ClampUnitFloat(controllerBaseLevel * ControllerLowMotorBaseMix(_audioHapticsVoiceFilterSelection) * _audioHapticsStrengthScale), 0.70f));
    float targetHighAmplitude = ClampUnitFloat(powf(ClampUnitFloat(((controllerTransientLevel * ControllerHighMotorTransientMix(_audioHapticsVoiceFilterSelection)) + (controllerBaseLevel * ControllerHighMotorBaseBleed(_audioHapticsVoiceFilterSelection))) * _audioHapticsStrengthScale), 0.74f));
    if (_audioHapticsVoiceFilterSelection == StreamAudioHapticsVoiceFilterSelectionHigh && targetLowAmplitude < 0.0060f) {
        targetLowAmplitude = 0.0f;
    }
    else if (targetLowAmplitude < 0.0025f) {
        targetLowAmplitude = 0.0f;
    }
    if (_audioHapticsVoiceFilterSelection == StreamAudioHapticsVoiceFilterSelectionHigh && targetHighAmplitude < 0.0040f) {
        targetHighAmplitude = 0.0f;
    }
    else if (targetHighAmplitude < 0.0025f) {
        targetHighAmplitude = 0.0f;
    }

    _audioControllerState.smoothedLowMotorAmplitude = ApplyAttackReleaseSmoothing(_audioControllerState.smoothedLowMotorAmplitude,
                                                                                  targetLowAmplitude,
                                                                                  0.42f,
                                                                                  ControllerLowMotorReleaseAlpha(_audioHapticsVoiceFilterSelection));
    _audioControllerState.smoothedHighMotorAmplitude = ApplyAttackReleaseSmoothing(_audioControllerState.smoothedHighMotorAmplitude,
                                                                                   targetHighAmplitude,
                                                                                   0.48f,
                                                                                   ControllerHighMotorReleaseAlpha(_audioHapticsVoiceFilterSelection));
    if (_audioHapticsVoiceFilterSelection == StreamAudioHapticsVoiceFilterSelectionHigh && _audioControllerState.smoothedLowMotorAmplitude < 0.0035f) {
        _audioControllerState.smoothedLowMotorAmplitude = 0.0f;
    }
    else if (_audioControllerState.smoothedLowMotorAmplitude < 0.0012f) {
        _audioControllerState.smoothedLowMotorAmplitude = 0.0f;
    }
    if (_audioHapticsVoiceFilterSelection == StreamAudioHapticsVoiceFilterSelectionHigh && _audioControllerState.smoothedHighMotorAmplitude < 0.0030f) {
        _audioControllerState.smoothedHighMotorAmplitude = 0.0f;
    }
    else if (_audioControllerState.smoothedHighMotorAmplitude < 0.0012f) {
        _audioControllerState.smoothedHighMotorAmplitude = 0.0f;
    }

    [self updateControllerAudioHapticsWithLowAmplitude:AudioHapticsAmplitudeFromUnitFloat(_audioControllerState.smoothedLowMotorAmplitude)
                                         highAmplitude:AudioHapticsAmplitudeFromUnitFloat(_audioControllerState.smoothedHighMotorAmplitude)];
}

- (void)stopAudioHaptics {
    [self clearAudioDrivenRumbleState];
}

- (void)updateAudioHapticsEnabled:(BOOL)enabled
                     outputTarget:(NSInteger)outputTarget
                         strength:(NSInteger)strength
             voiceFilterSelection:(NSInteger)voiceFilterSelection
         keepControllerRumble:(BOOL)keepControllerRumble {
    NSInteger normalizedOutputTarget = NormalizedAudioHapticsOutputTargetValue(outputTarget);
    NSInteger normalizedStrength = NormalizedAudioHapticsStrengthValue(strength);
    NSInteger normalizedVoiceFilterSelection = NormalizedAudioHapticsVoiceFilterSelectionValue(voiceFilterSelection);
    BOOL configurationChanged = (_audioHapticsEnabled != enabled) ||
                                (_audioHapticsOutputTarget != normalizedOutputTarget) ||
                                (_audioHapticsVoiceFilterSelection != normalizedVoiceFilterSelection) ||
                                (_audioHapticsKeepControllerRumble != keepControllerRumble) ||
                                (fabsf(_audioHapticsStrengthScale - MAX(0.25f, MIN((float)normalizedStrength / 100.0f, 2.0f))) > FLT_EPSILON);

    if (!configurationChanged) {
        return;
    }

    [self clearAudioDrivenRumbleState];

    _audioHapticsEnabled = enabled;
    _audioHapticsOutputTarget = normalizedOutputTarget;
    _audioHapticsStrengthScale = MAX(0.25f, MIN((float)normalizedStrength / 100.0f, 2.0f));
    _audioHapticsVoiceFilterSelection = normalizedVoiceFilterSelection;
    _audioHapticsKeepControllerRumble = keepControllerRumble;

    [self syncAudioHapticsResources];

    for (Controller *controller in [_controllers allValues]) {
        [self applyCombinedRumbleForController:controller];
    }
}


- (void) setMotionEventState:(uint16_t)controllerNumber motionType:(uint8_t)motionType reportRateHz:(uint16_t)reportRateHz
{
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        Controller* controller = [_controllers objectForKey:[NSNumber numberWithInteger:controllerNumber]];
//        if (controller == nil) {
//            // No connected controller for this player
//            return;
//        }
//        
//        if (controller.gamepad.motion == nil) {
//            // No motion supported for this controller
//            return;
//        }
        NSInteger motionMode = _motionMode; //motionMode 0 = auto | 1 = always device | 2 = always controller
        NSLog(@"axixi-motionMode %ld", (long)motionMode);
        if (motionMode==2) {
            if (controller == nil) {
                // No connected controller for this player
                return;
            }
            if (controller.gamepad.motion == nil) {
                // No motion supported for this controller
                return;
            }
            NSLog(@"axixi-gamepad %@", controller.gamepad.description);
            NSLog(@"axixi-gamepad %@", controller.gamepad.productCategory);
        }
        //陀螺仪
        #if !TARGET_OS_TV //tvOS has no device motion
            if(controllerNumber < 2 && motionMode != 2){
                //motionMode 0 = auto | 1 = always device | 2 = always controller
                if(controller == nil || controller.gamepad.motion == nil || motionMode == 1){
                    //Player has no controller *or* no motion for controller 1 *or* wants to override controller 1 motion with device motion
                    //using device motion
                    if (controller == nil) {
                        // No connected controller for this player, use the _oscController instead
                        controller = _oscController;
                    }

                    switch (motionType) {
                        case LI_MOTION_TYPE_ACCEL:
                            [controller.accelTimer invalidate];
                            controller.accelTimer = nil;

                            // Reset the last motion sample
                            CMAcceleration emptyDeviceAccelSample = {};
                            controller.lastDeviceAccelSample = emptyDeviceAccelSample;

                            if (!reportRateHz) {
                                [self stopDeviceMotionUpdatesIfIdleForController:controller];
                                break;
                            }

                            [self startDeviceMotionUpdatesForController:controller reportRateHz:reportRateHz];

                            {dispatch_sync(dispatch_get_main_queue(), ^{
                                controller.accelTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / reportRateHz repeats:YES block:^(NSTimer *timer) {
                                    // Don't send duplicate samples
                                    CMAcceleration lastDeviceAccelSample = controller.lastDeviceAccelSample;
                                    CMAcceleration deviceAccelSample = controller.motionManager.deviceMotion.userAcceleration;
                                    //userAcceleration does not contain gravity, add gravity to x, y and z values:
                                    deviceAccelSample.x += controller.motionManager.deviceMotion.gravity.x;
                                    deviceAccelSample.y += controller.motionManager.deviceMotion.gravity.y;
                                    deviceAccelSample.z += controller.motionManager.deviceMotion.gravity.z;

                                    if (memcmp(&deviceAccelSample, &lastDeviceAccelSample, sizeof(deviceAccelSample)) == 0) {
                                        return;
                                    }
                                    controller.lastDeviceAccelSample = deviceAccelSample;

                                    // Convert g to m/s^2
                                    if(UIApplication.sharedApplication.windows.firstObject.windowScene.interfaceOrientation == 4){ //check for landscape left or landscape right
                                        LiSendControllerMotionEvent((uint8_t)controllerNumber,
                                                                    LI_MOTION_TYPE_ACCEL,
                                                                    deviceAccelSample.y * -9.80665f,
                                                                    deviceAccelSample.z * -9.80665f,
                                                                    deviceAccelSample.x * -9.80665f);
                                    }
                                    else{
                                        LiSendControllerMotionEvent((uint8_t)controllerNumber,
                                                                    LI_MOTION_TYPE_ACCEL,
                                                                    deviceAccelSample.y * +9.80665f,
                                                                    deviceAccelSample.z * -9.80665f,
                                                                    deviceAccelSample.x * +9.80665f);
                                    }
                                }];
                            });}
                            break;
                        case LI_MOTION_TYPE_GYRO:
                            [controller.gyroTimer invalidate];
                            controller.gyroTimer = nil;

                            // Reset the last motion sample
                            CMRotationRate emptyDeviceGyroSample = {};
                            controller.lastDeviceGyroSample = emptyDeviceGyroSample;

                            if (!reportRateHz) {
                                [self stopDeviceMotionUpdatesIfIdleForController:controller];
                                break;
                            }

                            [self startDeviceMotionUpdatesForController:controller reportRateHz:reportRateHz];

                            dispatch_sync(dispatch_get_main_queue(), ^{
                                controller.gyroTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / reportRateHz repeats:YES block:^(NSTimer *timer) {

                                    // Don't send duplicate samples
                                    CMRotationRate lastDeviceGyroSample = controller.lastDeviceGyroSample;
                                    CMRotationRate deviceGyroSample = controller.motionManager.deviceMotion.rotationRate;
                                    if (memcmp(&deviceGyroSample, &lastDeviceGyroSample, sizeof(deviceGyroSample)) == 0) {
                                        return;
                                    }
                                    controller.lastDeviceGyroSample = deviceGyroSample;

                                    // Convert rad/s to deg/s
                                    if(UIApplication.sharedApplication.windows.firstObject.windowScene.interfaceOrientation == 4){//check for landscape left or landscape right
                                        LiSendControllerMotionEvent((uint8_t)controllerNumber,
                                                                    LI_MOTION_TYPE_GYRO,
                                                                    deviceGyroSample.y * 57.2957795f,
                                                                    deviceGyroSample.z * 57.2957795f,
                                                                    deviceGyroSample.x * 57.2957795f);
                                    }
                                    else{
                                        LiSendControllerMotionEvent((uint8_t)controllerNumber,
                                                                    LI_MOTION_TYPE_GYRO,
                                                                    deviceGyroSample.y * -57.2957795f,
                                                                    deviceGyroSample.z * 57.2957795f,
                                                                    deviceGyroSample.x * -57.2957795f);
                                    }

                                }];
                            });
                            break;
                    }
                    return;
                }
            }
        #endif
        
        
        switch (motionType) {
            case LI_MOTION_TYPE_ACCEL:
                [controller.accelTimer invalidate];
                controller.accelTimer = nil;
                                                                
                if (reportRateHz && controller.gamepad.motion.hasGravityAndUserAcceleration) {
                    // Reset the last motion sample
                    GCAcceleration emptyAccelSample = {};
                    controller.lastAccelSample = emptyAccelSample;
                    
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        controller.accelTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / reportRateHz repeats:YES block:^(NSTimer *timer) {
                            // Don't send duplicate samples
                            GCAcceleration lastAccelSample = controller.lastAccelSample;
                            GCAcceleration accelSample = controller.gamepad.motion.acceleration;
                            if (memcmp(&accelSample, &lastAccelSample, sizeof(accelSample)) == 0) {
                                return;
                            }
                            controller.lastAccelSample = accelSample;
                            
                            // Convert g to m/s^2
                            LiSendControllerMotionEvent((uint8_t)controllerNumber,
                                                        LI_MOTION_TYPE_ACCEL,
                                                        accelSample.x * -9.80665f,
                                                        accelSample.y * -9.80665f,
                                                        accelSample.z * -9.80665f);
                        }];
                    });
                }
                break;
                
            case LI_MOTION_TYPE_GYRO:
                [controller.gyroTimer invalidate];
                controller.gyroTimer = nil;
                
                if (reportRateHz && controller.gamepad.motion.hasRotationRate) {
                    // Reset the last motion sample
                    GCRotationRate emptyGyroSample = {};
                    controller.lastGyroSample = emptyGyroSample;
                    
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        controller.gyroTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / reportRateHz repeats:YES block:^(NSTimer *timer) {
                            // Don't send duplicate samples
                            GCRotationRate lastGyroSample = controller.lastGyroSample;
                            GCRotationRate gyroSample = controller.gamepad.motion.rotationRate;
                            if (memcmp(&gyroSample, &lastGyroSample, sizeof(gyroSample)) == 0) {
                                return;
                            }
                            controller.lastGyroSample = gyroSample;
                            
                            // Convert rad/s to deg/s
                            LiSendControllerMotionEvent((uint8_t)controllerNumber,
                                                        LI_MOTION_TYPE_GYRO,
                                                        gyroSample.x * 57.2957795f,
                                                        gyroSample.z * 57.2957795f,
                                                        gyroSample.y * -57.2957795f);
                        }];
                    });
                }
                break;
        }
        
        // Set the motion sensor state if they require manual activation
        if (controller.gamepad.motion.sensorsRequireManualActivation) {
            if (controller.gyroTimer || controller.accelTimer) {
                controller.gamepad.motion.sensorsActive = YES;
            }
            else {
                controller.gamepad.motion.sensorsActive = NO;
            }
        }
    }
}

-(void) setControllerLed:(uint16_t)controllerNumber r:(uint8_t)r g:(uint8_t)g b:(uint8_t)b {
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        Controller* controller = [_controllers objectForKey:[NSNumber numberWithInteger:controllerNumber]];
        if (controller == nil) {
            // No connected controller for this player
            return;
        }
        
        if (controller.gamepad.light == nil) {
            // No LED control supported for this controller
            return;
        }
        
        controller.gamepad.light.color = [[GCColor alloc] initWithRed:(r / 255.0f) green:(g / 255.0f) blue:(b / 255.0f)];
    }
}

-(void) updateLeftStick:(Controller*)controller x:(short)x y:(short)y
{
    @synchronized(controller) {
        controller.lastLeftStickX = x;
        controller.lastLeftStickY = y;
    }
}

-(void) updateRightStick:(Controller*)controller x:(short)x y:(short)y
{
    @synchronized(controller) {
        controller.lastRightStickX = x;
        controller.lastRightStickY = y;
    }
}

-(void) updateLeftTrigger:(Controller*)controller left:(unsigned char)left
{
    @synchronized(controller) {
        controller.lastLeftTrigger = left;
    }
}

-(void) updateRightTrigger:(Controller*)controller right:(unsigned char)right
{
    @synchronized(controller) {
        controller.lastRightTrigger = right;
    }
}

-(void) updateTriggers:(Controller*) controller left:(unsigned char)left right:(unsigned char)right
{
    @synchronized(controller) {
        controller.lastLeftTrigger = left;
        controller.lastRightTrigger = right;
    }
}

-(void) handleSpecialCombosReleased:(Controller*)controller releasedButtons:(int)releasedButtons
{
    if ((controller.emulatingButtonFlags & EMULATING_SELECT) && (releasedButtons & (LB_FLAG | PLAY_FLAG))) {
        controller.lastButtonFlags &= ~BACK_FLAG;
        controller.emulatingButtonFlags &= ~EMULATING_SELECT;
    }
    
    if (controller.emulatingButtonFlags & EMULATING_SPECIAL) {
        // If Select is emulated, we use RB+Start to emulate special, otherwise we use Start+Select
        if (controller.supportedEmulationFlags & EMULATING_SELECT) {
            if (releasedButtons & (RB_FLAG | PLAY_FLAG)) {
                controller.lastButtonFlags &= ~SPECIAL_FLAG;
                controller.emulatingButtonFlags &= ~EMULATING_SPECIAL;
            }
        }
        else {
            if (releasedButtons & (BACK_FLAG | PLAY_FLAG)) {
                controller.lastButtonFlags &= ~SPECIAL_FLAG;
                controller.emulatingButtonFlags &= ~EMULATING_SPECIAL;
            }
        }
    }
}

-(void) handleSpecialCombosPressed:(Controller*)controller pressedButtons:(int)pressedButtons
{
    // Special button combos for select and special
    if (controller.lastButtonFlags & PLAY_FLAG) {
        // If LB and start are down, trigger select
        if (controller.lastButtonFlags & LB_FLAG) {
            if (controller.supportedEmulationFlags & EMULATING_SELECT) {
                controller.lastButtonFlags |= BACK_FLAG;
                controller.lastButtonFlags &= ~(pressedButtons & (PLAY_FLAG | LB_FLAG));
                controller.emulatingButtonFlags |= EMULATING_SELECT;
            }
        }
        else if (controller.supportedEmulationFlags & EMULATING_SPECIAL) {
            // If Select is emulated too, use RB+Start to emulate special
            if (controller.supportedEmulationFlags & EMULATING_SELECT) {
                if (controller.lastButtonFlags & RB_FLAG) {
                    controller.lastButtonFlags |= SPECIAL_FLAG;
                    controller.lastButtonFlags &= ~(pressedButtons & (PLAY_FLAG | RB_FLAG));
                    controller.emulatingButtonFlags |= EMULATING_SPECIAL;
                }
            }
            else {
                // If Select is physical, use Start+Select to emulate special
                if (controller.lastButtonFlags & BACK_FLAG) {
                    controller.lastButtonFlags |= SPECIAL_FLAG;
                    controller.lastButtonFlags &= ~(pressedButtons & (PLAY_FLAG | BACK_FLAG));
                    controller.emulatingButtonFlags |= EMULATING_SPECIAL;
                }
            }
        }
    }
}

-(void) updateButtonFlags:(Controller*)controller flags:(int)flags
{
    @synchronized(controller) {
        controller.lastButtonFlags = flags;
        
        // This must be called before handleSpecialCombosPressed
        // because we clear the original button flags there
        int releasedButtons = (controller.lastButtonFlags ^ flags) & ~flags;
        int pressedButtons = (controller.lastButtonFlags ^ flags) & flags;
        
        [self handleSpecialCombosReleased:controller releasedButtons:releasedButtons];
        
        [self handleSpecialCombosPressed:controller pressedButtons:pressedButtons];
    }
}

-(void) setButtonFlag:(Controller*)controller flags:(int)flags
{
    @synchronized(controller) {
        controller.lastButtonFlags |= flags;
        [self handleSpecialCombosPressed:controller pressedButtons:flags];
    }
}

-(void) clearButtonFlag:(Controller*)controller flags:(int)flags
{
    @synchronized(controller) {
        controller.lastButtonFlags &= ~flags;
        [self handleSpecialCombosReleased:controller releasedButtons:flags];
    }
}

-(void) resetPendingGameMenuHoldStateForController:(Controller*)controller
{
    [controller.menuHoldTimer invalidate];
    controller.menuHoldTimer = nil;
    controller.suppressPlayButtonUntilRelease = NO;
    controller.didTriggerGameMenuFromHold = NO;
}

-(void) triggerPendingStartButtonTapForController:(Controller*)controller
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self setButtonFlag:controller flags:PLAY_FLAG];
        [self updateFinished:controller];
        usleep(100 * 1000);
        [self clearButtonFlag:controller flags:PLAY_FLAG];
        [self updateFinished:controller];
    });
}

-(void) handleGameMenuStartHoldTimerFired:(NSTimer*)timer
{
    Controller *controller = (Controller *)timer.userInfo;
    if (controller == nil) {
        return;
    }

    @synchronized(controller) {
        controller.menuHoldTimer = nil;
        if (!controller.suppressPlayButtonUntilRelease || controller.didTriggerGameMenuFromHold) {
            return;
        }
        controller.didTriggerGameMenuFromHold = YES;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_delegate gameMenuRequested];
    });
}

-(BOOL) shouldUseLongPressStartForGameMenuForController:(Controller*)controller pressed:(BOOL)pressed
{
    if (!_longPressStartForGameMenuEnabled || controller == nil) {
        return NO;
    }

    if (!pressed) {
        return controller.suppressPlayButtonUntilRelease;
    }

    int comboMask = LB_FLAG | RB_FLAG | BACK_FLAG | SPECIAL_FLAG;
    return (controller.lastButtonFlags & comboMask) == 0;
}

-(void) updateMenuButtonLongPressStateForController:(Controller*)controller pressed:(BOOL)pressed
{
    if (controller == nil) {
        return;
    }

    if (pressed) {
        if (controller.suppressPlayButtonUntilRelease || controller.didTriggerGameMenuFromHold) {
            return;
        }

        controller.suppressPlayButtonUntilRelease = YES;
        controller.didTriggerGameMenuFromHold = NO;
        [controller.menuHoldTimer invalidate];
        controller.menuHoldTimer = [NSTimer scheduledTimerWithTimeInterval:kStartButtonHoldDurationForGameMenu
                                                                    target:self
                                                                  selector:@selector(handleGameMenuStartHoldTimerFired:)
                                                                  userInfo:controller
                                                                   repeats:NO];
        return;
    }

    BOOL shouldSendPlayTap = controller.suppressPlayButtonUntilRelease && !controller.didTriggerGameMenuFromHold;
    [self resetPendingGameMenuHoldStateForController:controller];
    if (shouldSendPlayTap) {
        [self triggerPendingStartButtonTapForController:controller];
    }
}

-(uint16_t) getActiveGamepadMask
{
    return (_multiController ? _controllerNumbers : 1) | (_oscEnabled ? 1 : 0);
}

-(void) updateFinished:(Controller*)controller
{
    BOOL exitRequested = NO;
    
    [_controllerStreamLock lock];
    @synchronized(controller) {
        // Handle Start+Select+L1+R1 gamepad quit combo
        if (controller.lastButtonFlags == (PLAY_FLAG | BACK_FLAG | LB_FLAG | RB_FLAG)) {
            controller.lastButtonFlags = 0;
            exitRequested = YES;
        }
        
        // Only send controller events if we successfully reported controller arrival
        if ([self reportControllerArrival:controller]) {
            uint32_t buttonFlags = controller.lastButtonFlags;
            uint8_t leftTrigger = controller.lastLeftTrigger;
            uint8_t rightTrigger = controller.lastRightTrigger;
            int16_t leftStickX = controller.lastLeftStickX;
            int16_t leftStickY = controller.lastLeftStickY;
            int16_t rightStickX = controller.lastRightStickX;
            int16_t rightStickY = controller.lastRightStickY;
            
            // If this is merged with another controller, combine the inputs
            if (controller.mergedWithController) {
                buttonFlags |= controller.mergedWithController.lastButtonFlags;
                leftTrigger = MAX(leftTrigger, controller.mergedWithController.lastLeftTrigger);
                rightTrigger = MAX(rightTrigger, controller.mergedWithController.lastRightTrigger);
                leftStickX = MAX_MAGNITUDE(leftStickX, controller.mergedWithController.lastLeftStickX);
                leftStickY = MAX_MAGNITUDE(leftStickY, controller.mergedWithController.lastLeftStickY);
                rightStickX = MAX_MAGNITUDE(rightStickX, controller.mergedWithController.lastRightStickX);
                rightStickY = MAX_MAGNITUDE(rightStickY, controller.mergedWithController.lastRightStickY);
            }
            
            // Player 1 is always present for OSC
            LiSendMultiControllerEvent(_multiController ? controller.playerIndex : 0, [self getActiveGamepadMask],
                                       buttonFlags, leftTrigger, rightTrigger,
                                       leftStickX, leftStickY, rightStickX, rightStickY);
        }
    }
    [_controllerStreamLock unlock];
    
    if (exitRequested) {
        // Invoke the delegate callback on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_delegate streamExitRequested];
        });
    }
}

+(BOOL) hasKeyboardOrMouse {
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        return GCMouse.mice.count > 0 || GCKeyboard.coalescedKeyboard != nil;
    }
    else {
        return NO;
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

-(void) unregisterControllerCallbacks:(GCController*) controller
{
    if (controller != NULL) {
        controller.controllerPausedHandler = NULL;
        
        if (controller.extendedGamepad != NULL) {
            // Re-enable system gestures on the gamepad buttons now
            if (@available(iOS 14.0, tvOS 14.0, *)) {
                for (GCControllerElement* element in controller.physicalInputProfile.allElements) {
                    element.preferredSystemGestureState = GCSystemGestureStateEnabled;
                }
            }
            
            controller.extendedGamepad.valueChangedHandler = NULL;
        }
    }
}

-(void) initializeControllerHaptics:(Controller*) controller
{
    controller.lowFreqMotor = [HapticContext createContextForLowFreqMotor:controller.gamepad];
    controller.highFreqMotor = [HapticContext createContextForHighFreqMotor:controller.gamepad];
    controller.leftTriggerMotor = [HapticContext createContextForLeftTrigger:controller.gamepad];
    controller.rightTriggerMotor = [HapticContext createContextForRightTrigger:controller.gamepad];
    if (_audioHapticsEnabled &&
        _audioHapticsOutputTarget == StreamAudioHapticsOutputTargetController &&
        _rumbleMode != StreamRumbleModeSelectionController) {
        controller.audioLowFreqMotor = [HapticContext createForcedControllerLowFreqMotor:controller.gamepad];
        controller.audioHighFreqMotor = [HapticContext createForcedControllerHighFreqMotor:controller.gamepad];
    }
}

-(void) cleanupControllerHaptics:(Controller*) controller
{
    [controller.lowFreqMotor cleanup];
    [controller.highFreqMotor cleanup];
    [controller.leftTriggerMotor cleanup];
    [controller.rightTriggerMotor cleanup];
    [controller.audioLowFreqMotor cleanup];
    [controller.audioHighFreqMotor cleanup];
}

-(void) cleanupControllerMotion:(Controller*) controller
{
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        // Stop sensor sampling timers
        [controller.gyroTimer invalidate];
        controller.gyroTimer = nil;
        [controller.accelTimer invalidate];
        controller.accelTimer = nil;
        
        // Disable motion sensors if they require manual activation
        if (controller.gamepad && controller.gamepad.motion && controller.gamepad.motion.sensorsRequireManualActivation) {
            controller.gamepad.motion.sensorsActive = NO;
        }

#if !TARGET_OS_TV
        [self stopDeviceMotionUpdatesIfIdleForController:controller];
#endif
    }
}

-(void) initializeControllerBattery:(Controller*) controller
{
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        if (controller.gamepad.battery) {
            // Poll for updated battery status every 30 seconds
            controller.batteryTimer = [NSTimer scheduledTimerWithTimeInterval:30 repeats:YES block:^(NSTimer *timer) {
                if (controller.lastBatteryState != controller.gamepad.battery.batteryState ||
                    controller.lastBatteryLevel != controller.gamepad.battery.batteryLevel) {
                    uint8_t batteryState;
                    
                    switch (controller.gamepad.battery.batteryState) {
                        case GCDeviceBatteryStateFull:
                            batteryState = LI_BATTERY_STATE_FULL;
                            break;
                        case GCDeviceBatteryStateCharging:
                            batteryState = LI_BATTERY_STATE_CHARGING;
                            break;
                        case GCDeviceBatteryStateDischarging:
                            batteryState = LI_BATTERY_STATE_DISCHARGING;
                            break;
                        case GCDeviceBatteryStateUnknown:
                        default:
                            batteryState = LI_BATTERY_STATE_UNKNOWN;
                            break;
                    }
                    
                    LiSendControllerBatteryEvent(controller.playerIndex, batteryState, (uint8_t)(controller.gamepad.battery.batteryLevel * 100));
                    
                    controller.lastBatteryState = controller.gamepad.battery.batteryState;
                    controller.lastBatteryLevel = controller.gamepad.battery.batteryLevel;
                }
            }];
            
            // Fire the timer immediately to send the initial battery state
            [controller.batteryTimer fire];
        }
    }
}

-(void) cleanupControllerBattery:(Controller*) controller
{
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        [controller.batteryTimer invalidate];
    }
}

-(BOOL) reportControllerArrival:(Controller*) limeController
{
    // Only report arrival once
    if (limeController.reportedArrival) {
        return YES;
    }
    
    uint8_t type = LI_CTYPE_UNKNOWN;
    uint16_t capabilities = 0;
    uint32_t supportedButtonFlags = 0;
    
    GCController *controller = limeController.gamepad;
    if (controller) {
        // This is a physical controller with a corresponding GCController object
        
        // Start is always present
        supportedButtonFlags |= PLAY_FLAG;
        // Detect buttons present in the GCExtendedGamepad profile
        if (controller.extendedGamepad.dpad) {
            supportedButtonFlags |= UP_FLAG | DOWN_FLAG | LEFT_FLAG | RIGHT_FLAG;
        }
        if (controller.extendedGamepad.leftShoulder) {
            supportedButtonFlags |= LB_FLAG;
        }
        if (controller.extendedGamepad.rightShoulder) {
            supportedButtonFlags |= RB_FLAG;
        }
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            if (controller.extendedGamepad.buttonOptions) {
                supportedButtonFlags |= BACK_FLAG;
            }
        }
        if (@available(iOS 14.0, tvOS 14.0, *)) {
            if (controller.extendedGamepad.buttonHome) {
                supportedButtonFlags |= SPECIAL_FLAG;
            }
        }
        if (controller.extendedGamepad.buttonA) {
            supportedButtonFlags |= A_FLAG;
        }
        if (controller.extendedGamepad.buttonB) {
            supportedButtonFlags |= B_FLAG;
        }
        if (controller.extendedGamepad.buttonX) {
            supportedButtonFlags |= X_FLAG;
        }
        if (controller.extendedGamepad.buttonY) {
            supportedButtonFlags |= Y_FLAG;
        }
        if (@available(iOS 12.1, tvOS 12.1, *)) {
            if (controller.extendedGamepad.leftThumbstickButton) {
                supportedButtonFlags |= LS_CLK_FLAG;
            }
            if (controller.extendedGamepad.rightThumbstickButton) {
                supportedButtonFlags |= RS_CLK_FLAG;
            }
        }
        
        if (@available(iOS 14.0, tvOS 14.0, *)) {
            // Xbox One/Series controller
            if (controller.physicalInputProfile.buttons[GCInputXboxPaddleOne]) {
                supportedButtonFlags |= PADDLE1_FLAG;
            }
            if (controller.physicalInputProfile.buttons[GCInputXboxPaddleTwo]) {
                supportedButtonFlags |= PADDLE2_FLAG;
            }
            if (controller.physicalInputProfile.buttons[GCInputXboxPaddleThree]) {
                supportedButtonFlags |= PADDLE3_FLAG;
            }
            if (controller.physicalInputProfile.buttons[GCInputXboxPaddleFour]) {
                supportedButtonFlags |= PADDLE4_FLAG;
            }
            if (@available(iOS 15.0, tvOS 15.0, *)) {
                if (controller.physicalInputProfile.buttons[GCInputButtonShare]) {
                    supportedButtonFlags |= MISC_FLAG;
                }
            }
            
            // DualShock/DualSense controller
            if (controller.physicalInputProfile.buttons[GCInputDualShockTouchpadButton]) {
                supportedButtonFlags |= TOUCHPAD_FLAG;
            }
            if (controller.physicalInputProfile.dpads[GCInputDualShockTouchpadOne]) {
                capabilities |= LI_CCAP_TOUCHPAD;
            }
            
            if ([controller.extendedGamepad isKindOfClass:[GCXboxGamepad class]]) {
                type = LI_CTYPE_XBOX;
            }
            else if ([controller.extendedGamepad isKindOfClass:[GCDualShockGamepad class]]) {
                type = LI_CTYPE_PS;
            }
            
            if (@available(iOS 14.5, tvOS 14.5, *)) {
                if ([controller.extendedGamepad isKindOfClass:[GCDualSenseGamepad class]]) {
                    type = LI_CTYPE_PS;
                }
            }
            
            // Detect supported haptics localities
            if (controller.haptics) {
                if ([controller.haptics.supportedLocalities containsObject:GCHapticsLocalityHandles]) {
                    capabilities |= LI_CCAP_RUMBLE;
                }
                if ([controller.haptics.supportedLocalities containsObject:GCHapticsLocalityTriggers]) {
                    capabilities |= LI_CCAP_TRIGGER_RUMBLE;
                }
            }
            
            // Detect supported motion sensors
            if (controller.motion) {
                if (controller.motion.hasGravityAndUserAcceleration) {
                    capabilities |= LI_CCAP_ACCEL;
                }
                if (controller.motion.hasRotationRate) {
                    capabilities |= LI_CCAP_GYRO;
                }
            }
            
            // Detect RGB LED support
            if (controller.light) {
                capabilities |= LI_CCAP_RGB_LED;
            }
            
            // Detect battery support
            if (controller.battery) {
                capabilities |= LI_CCAP_BATTERY_STATE;
            }
        }
        else {
            // This is a virtual controller corresponding to our OSC

            // TODO: Support various layouts and button labels on the OSC
            type = LI_CTYPE_XBOX;
            capabilities = 0;
            supportedButtonFlags =
                PLAY_FLAG | BACK_FLAG | UP_FLAG | DOWN_FLAG | LEFT_FLAG | RIGHT_FLAG |
                LB_FLAG | RB_FLAG | LS_CLK_FLAG | RS_CLK_FLAG | A_FLAG | B_FLAG | X_FLAG | Y_FLAG;
        }
    }

    // Report the new controller to the host
    // NB: This will fail if the connection hasn't been fully established yet
    // and we will try again later.
    if (LiSendControllerArrivalEvent(controller.playerIndex,
                                     [self getActiveGamepadMask],
                                     type,
                                     supportedButtonFlags,
                                     capabilities) != 0) {
        return NO;
    }
    
    // Begin polling for battery status
    [self initializeControllerBattery:limeController];
    
    // Remember that we've reported arrival already
    limeController.reportedArrival = YES;
    return YES;
}

-(void) handleControllerTouchpad:(Controller*)controller touch:(GCControllerDirectionPad*)touch index:(int)index
{
    controller_touch_context_t context = index == 0 ? controller.primaryTouch : controller.secondaryTouch;
    
    // This magic is courtesy of SDL
    float normalizedX = (1.0f + touch.xAxis.value) * 0.5f;
    float normalizedY = 1.0f - (1.0f + touch.yAxis.value) * 0.5f;
    
    // If we went from a touch to no touch, generate a touch up event
    if ((context.lastX || context.lastY) && (!touch.xAxis.value && !touch.yAxis.value)) {
        LiSendControllerTouchEvent(controller.playerIndex, LI_TOUCH_EVENT_UP, index, normalizedX, normalizedY, 1.0f);
    }
    else if (touch.xAxis.value || touch.yAxis.value) {
        // If we went from no touch to a touch, generate a touch down event
        if (!context.lastX && !context.lastY) {
            LiSendControllerTouchEvent(controller.playerIndex, LI_TOUCH_EVENT_DOWN, index, normalizedX, normalizedY, 1.0f);
        }
        else if (context.lastX != touch.xAxis.value || context.lastY != touch.yAxis.value) {
            // Otherwise it's just a move
            LiSendControllerTouchEvent(controller.playerIndex, LI_TOUCH_EVENT_MOVE, index, normalizedX, normalizedY, 1.0f);
        }
    }
    
    // We have to assign the whole struct because this is a property rather than a standard
    // field that we could modify through a pointer.
    if (index == 0) {
        controller.primaryTouch = (controller_touch_context_t) {
            touch.xAxis.value,
            touch.yAxis.value
        };
    }
    else {
        controller.secondaryTouch = (controller_touch_context_t) {
            touch.xAxis.value,
            touch.yAxis.value
        };
    }
}

-(void) registerControllerCallbacks:(GCController*) controller
{
    if (controller != NULL) {
        // iOS 13 allows the Start button to behave like a normal button, however
        // older MFi controllers can send an instant down+up event for the start button
        // which means the button will not be down long enough to register on the PC.
        // To work around this issue, use the old controllerPausedHandler if the controller
        // doesn't have a Select button (which indicates it probably doesn't have a proper
        // Start button either).
        BOOL useLegacyPausedHandler = YES;
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            if (controller.extendedGamepad != nil &&
                controller.extendedGamepad.buttonOptions != nil) {
                useLegacyPausedHandler = NO;
            }
        }
        
        if (useLegacyPausedHandler) {
            controller.controllerPausedHandler = ^(GCController *controller) {
                Controller* limeController = [self->_controllers objectForKey:[NSNumber numberWithInteger:controller.playerIndex]];
                
                // Get off the main thread
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    [self setButtonFlag:limeController flags:PLAY_FLAG];
                    [self updateFinished:limeController];
                    
                    // Pause for 100 ms
                    usleep(100 * 1000);
                    
                    [self clearButtonFlag:limeController flags:PLAY_FLAG];
                    [self updateFinished:limeController];
                });
            };
        }
        
        if (controller.extendedGamepad != NULL) {
            // Disable system gestures on the gamepad to avoid interfering
            // with in-game controller actions
            if (@available(iOS 14.0, tvOS 14.0, *)) {
                for (GCControllerElement* element in controller.physicalInputProfile.allElements) {
                    element.preferredSystemGestureState = GCSystemGestureStateDisabled;
                }
            }
            
            controller.extendedGamepad.valueChangedHandler = ^(GCExtendedGamepad *gamepad, GCControllerElement *element) {
                Controller* limeController = [self->_controllers objectForKey:[NSNumber numberWithInteger:gamepad.controller.playerIndex]];
                short leftStickX, leftStickY;
                short rightStickX, rightStickY;
                unsigned char leftTrigger, rightTrigger;
                
                if (self->_swapABXYButtons) {
                    UPDATE_BUTTON_FLAG(limeController, B_FLAG, gamepad.buttonA.pressed);
                    UPDATE_BUTTON_FLAG(limeController, A_FLAG, gamepad.buttonB.pressed);
                    UPDATE_BUTTON_FLAG(limeController, Y_FLAG, gamepad.buttonX.pressed);
                    UPDATE_BUTTON_FLAG(limeController, X_FLAG, gamepad.buttonY.pressed);
                }
                else {
                    UPDATE_BUTTON_FLAG(limeController, A_FLAG, gamepad.buttonA.pressed);
                    UPDATE_BUTTON_FLAG(limeController, B_FLAG, gamepad.buttonB.pressed);
                    UPDATE_BUTTON_FLAG(limeController, X_FLAG, gamepad.buttonX.pressed);
                    UPDATE_BUTTON_FLAG(limeController, Y_FLAG, gamepad.buttonY.pressed);
                }
                
                UPDATE_BUTTON_FLAG(limeController, UP_FLAG, gamepad.dpad.up.pressed);
                UPDATE_BUTTON_FLAG(limeController, DOWN_FLAG, gamepad.dpad.down.pressed);
                UPDATE_BUTTON_FLAG(limeController, LEFT_FLAG, gamepad.dpad.left.pressed);
                UPDATE_BUTTON_FLAG(limeController, RIGHT_FLAG, gamepad.dpad.right.pressed);
                
                UPDATE_BUTTON_FLAG(limeController, LB_FLAG, gamepad.leftShoulder.pressed);
                UPDATE_BUTTON_FLAG(limeController, RB_FLAG, gamepad.rightShoulder.pressed);
                
                // Yay, iOS 12.1 now supports analog stick buttons
                if (@available(iOS 12.1, tvOS 12.1, *)) {
                    if (gamepad.leftThumbstickButton != nil) {
                        UPDATE_BUTTON_FLAG(limeController, LS_CLK_FLAG, gamepad.leftThumbstickButton.pressed);
                    }
                    if (gamepad.rightThumbstickButton != nil) {
                        UPDATE_BUTTON_FLAG(limeController, RS_CLK_FLAG, gamepad.rightThumbstickButton.pressed);
                    }
                }
                
                if (@available(iOS 13.0, tvOS 13.0, *)) {
                    // Options button is optional (only present on Xbox One S and PS4 gamepads)
                    if (gamepad.buttonOptions != nil) {
                        UPDATE_BUTTON_FLAG(limeController, BACK_FLAG, gamepad.buttonOptions.pressed);

                        // For older MFi gamepads, the menu button will already be handled by
                        // the controllerPausedHandler.
                        if ([self shouldUseLongPressStartForGameMenuForController:limeController pressed:gamepad.buttonMenu.pressed]) {
                            [self updateMenuButtonLongPressStateForController:limeController pressed:gamepad.buttonMenu.pressed];
                        }
                        else {
                            if (!gamepad.buttonMenu.pressed &&
                                (limeController.suppressPlayButtonUntilRelease || limeController.didTriggerGameMenuFromHold)) {
                                [self updateMenuButtonLongPressStateForController:limeController pressed:NO];
                            }
                            UPDATE_BUTTON_FLAG(limeController, PLAY_FLAG, gamepad.buttonMenu.pressed);
                        }
                    }
                }
                
                if (@available(iOS 14.0, tvOS 14.0, *)) {
                    // Home/Guide button is optional (only present on Xbox One S and PS4 gamepads)
                    if (gamepad.buttonHome != nil) {
                        UPDATE_BUTTON_FLAG(limeController, SPECIAL_FLAG, gamepad.buttonHome.pressed);
                    }
                    
                    // Xbox One/Series controllers
                    if (gamepad.controller.physicalInputProfile.buttons[GCInputXboxPaddleOne]) {
                        UPDATE_BUTTON_FLAG(limeController, PADDLE1_FLAG, gamepad.controller.physicalInputProfile.buttons[GCInputXboxPaddleOne].pressed);
                    }
                    if (gamepad.controller.physicalInputProfile.buttons[GCInputXboxPaddleTwo]) {
                        UPDATE_BUTTON_FLAG(limeController, PADDLE2_FLAG, gamepad.controller.physicalInputProfile.buttons[GCInputXboxPaddleTwo].pressed);
                    }
                    if (gamepad.controller.physicalInputProfile.buttons[GCInputXboxPaddleThree]) {
                        UPDATE_BUTTON_FLAG(limeController, PADDLE3_FLAG, gamepad.controller.physicalInputProfile.buttons[GCInputXboxPaddleThree].pressed);
                    }
                    if (gamepad.controller.physicalInputProfile.buttons[GCInputXboxPaddleFour]) {
                        UPDATE_BUTTON_FLAG(limeController, PADDLE4_FLAG, gamepad.controller.physicalInputProfile.buttons[GCInputXboxPaddleFour].pressed);
                    }
                    if (@available(iOS 15.0, tvOS 15.0, *)) {
                        if (gamepad.controller.physicalInputProfile.buttons[GCInputButtonShare]) {
                            UPDATE_BUTTON_FLAG(limeController, MISC_FLAG, gamepad.controller.physicalInputProfile.buttons[GCInputButtonShare].pressed);
                        }
                    }
                    
                    // DualShock/DualSense controllers
                    if (gamepad.controller.physicalInputProfile.buttons[GCInputDualShockTouchpadButton]) {
                        UPDATE_BUTTON_FLAG(limeController, TOUCHPAD_FLAG, gamepad.controller.physicalInputProfile.buttons[GCInputDualShockTouchpadButton].pressed);
                    }
                    if (gamepad.controller.physicalInputProfile.dpads[GCInputDualShockTouchpadOne]) {
                        [self handleControllerTouchpad:limeController
                                                 touch:gamepad.controller.physicalInputProfile.dpads[GCInputDualShockTouchpadOne]
                                                 index:0];
                    }
                    if (gamepad.controller.physicalInputProfile.dpads[GCInputDualShockTouchpadTwo]) {
                        [self handleControllerTouchpad:limeController
                                                 touch:gamepad.controller.physicalInputProfile.dpads[GCInputDualShockTouchpadTwo]
                                                 index:1];
                    }
                }
                
                leftStickX = gamepad.leftThumbstick.xAxis.value * 0x7FFE;
                leftStickY = gamepad.leftThumbstick.yAxis.value * 0x7FFE;
                
                rightStickX = gamepad.rightThumbstick.xAxis.value * 0x7FFE;
                rightStickY = gamepad.rightThumbstick.yAxis.value * 0x7FFE;
                
                leftTrigger = gamepad.leftTrigger.value * 0xFF;
                rightTrigger = gamepad.rightTrigger.value * 0xFF;
                
                [self updateLeftStick:limeController x:leftStickX y:leftStickY];
                [self updateRightStick:limeController x:rightStickX y:rightStickY];
                [self updateTriggers:limeController left:leftTrigger right:rightTrigger];
                [self updateFinished:limeController];
            };
        }
    } else {
        Log(LOG_W, @"Tried to register controller callbacks on NULL controller");
    }
}

-(void) unregisterMouseCallbacks:(GCMouse*)mouse API_AVAILABLE(ios(14.0)) {
    mouse.mouseInput.mouseMovedHandler = nil;
    
    mouse.mouseInput.leftButton.pressedChangedHandler = nil;
    mouse.mouseInput.middleButton.pressedChangedHandler = nil;
    mouse.mouseInput.rightButton.pressedChangedHandler = nil;
    
    for (GCControllerButtonInput* auxButton in mouse.mouseInput.auxiliaryButtons) {
        auxButton.pressedChangedHandler = nil;
    }
    
#if TARGET_OS_TV
    mouse.mouseInput.scroll.xAxis.valueChangedHandler = nil;
    mouse.mouseInput.scroll.yAxis.valueChangedHandler = nil;
#endif
}

-(void) registerMouseCallbacks:(GCMouse*) mouse API_AVAILABLE(ios(14.0)) {
    mouse.mouseInput.mouseMovedHandler = ^(GCMouseInput * _Nonnull mouse, float deltaX, float deltaY) {
        if (self->_remoteMouseMode || self->_mouseInputSuppressed) {
            return;
        }

        float adjustedDeltaX = AdjustMouseDeltaForLowSpeed(deltaX) / MOUSE_SPEED_DIVISOR;
        float adjustedDeltaY = AdjustMouseDeltaForLowSpeed(deltaY) / MOUSE_SPEED_DIVISOR;

        self->accumulatedDeltaX += adjustedDeltaX * self->_relativeMouseSensitivityScale;
        self->accumulatedDeltaY += -adjustedDeltaY * self->_relativeMouseSensitivityScale;
        
        short truncatedDeltaX = ConsumeAccumulatedMouseDelta(&self->accumulatedDeltaX);
        short truncatedDeltaY = ConsumeAccumulatedMouseDelta(&self->accumulatedDeltaY);
        
        if (truncatedDeltaX != 0 || truncatedDeltaY != 0) {
            LiSendMouseMoveEvent(truncatedDeltaX, truncatedDeltaY);
        }
    };
    
    mouse.mouseInput.leftButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        if (self->_remoteMouseMode || self->_mouseInputSuppressed) {
            return;
        }
        LiSendMouseButtonEvent(pressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    };
    mouse.mouseInput.middleButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        if (self->_remoteMouseMode || self->_mouseInputSuppressed) {
            return;
        }
        LiSendMouseButtonEvent(pressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE, BUTTON_MIDDLE);
    };
    mouse.mouseInput.rightButton.pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
        if (self->_remoteMouseMode || self->_mouseInputSuppressed) {
            return;
        }
        LiSendMouseButtonEvent(pressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
    };
    
    if (mouse.mouseInput.auxiliaryButtons != nil) {
        if (mouse.mouseInput.auxiliaryButtons.count >= 1) {
            mouse.mouseInput.auxiliaryButtons[0].pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
                if (self->_remoteMouseMode || self->_mouseInputSuppressed) {
                    return;
                }
                LiSendMouseButtonEvent(pressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE, BUTTON_X1);
            };
        }
        if (mouse.mouseInput.auxiliaryButtons.count >= 2) {
            mouse.mouseInput.auxiliaryButtons[1].pressedChangedHandler = ^(GCControllerButtonInput * _Nonnull button, float value, BOOL pressed) {
                if (self->_remoteMouseMode || self->_mouseInputSuppressed) {
                    return;
                }
                LiSendMouseButtonEvent(pressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE, BUTTON_X2);
            };
        }
    }
    
    // We use UIPanGestureRecognizer on iPadOS because it allows us to distinguish
    // between discrete and continuous scroll events and also works around a bug
    // in iPadOS 15 where discrete scroll events are dropped. tvOS only supports
    // GCMouse for mice, so we will have to just use it and hope for the best.
#if TARGET_OS_TV
    mouse.mouseInput.scroll.xAxis.valueChangedHandler = ^(GCControllerAxisInput * _Nonnull axis, float value) {
        self->accumulatedScrollX += value;
        
        short truncatedScrollX = (short)self->accumulatedScrollX;
        
        if (truncatedScrollX != 0) {
            // Direction is reversed from vertical scrolling
            LiSendHighResHScrollEvent(-truncatedScrollX * 20);
            
            self->accumulatedScrollX -= truncatedScrollX;
        }
    };
    mouse.mouseInput.scroll.yAxis.valueChangedHandler = ^(GCControllerAxisInput * _Nonnull axis, float value) {
        self->accumulatedScrollY += value;
        
        short truncatedScrollY = (short)self->accumulatedScrollY;
        
        if (truncatedScrollY != 0) {
            LiSendHighResScrollEvent(truncatedScrollY * 20);
            
            self->accumulatedScrollY -= truncatedScrollY;
        }
    };
#endif
}

-(Controller*) assignController:(GCController*)controller {
    for (int i = 0; i < 4; i++) {
        if (!(_controllerNumbers & (1 << i))) {
            _controllerNumbers |= (1 << i);
            controller.playerIndex = i;
            
            Controller* limeController = [[Controller alloc] init];
            limeController.playerIndex = i;
            limeController.supportedEmulationFlags = EMULATING_SPECIAL | EMULATING_SELECT;
            limeController.gamepad = controller;

            // If this is player 0, it shares state with the OSC
            limeController.mergedWithController = _oscController;
            _oscController.mergedWithController = limeController;
            
            if (@available(iOS 13.0, tvOS 13.0, *)) {
                if (controller.extendedGamepad != nil &&
                    controller.extendedGamepad.buttonOptions != nil) {
                    // Disable select button emulation since we have a physical select button
                    limeController.supportedEmulationFlags &= ~EMULATING_SELECT;
                }
            }
            
            if (@available(iOS 14.0, tvOS 14.0, *)) {
                if (controller.extendedGamepad != nil &&
                    controller.extendedGamepad.buttonHome != nil) {
                    // Disable special button emulation since we have a physical special button
                    limeController.supportedEmulationFlags &= ~EMULATING_SPECIAL;
                }
            }
            
            // Prepare controller haptics for use
            [self initializeControllerHaptics:limeController];

            [_controllers setObject:limeController forKey:[NSNumber numberWithInteger:controller.playerIndex]];
            
            Log(LOG_I, @"Assigning controller index: %d", i);
            return limeController;
        }
    }
    
    return nil;
}

-(Controller*) getOscController {
    return _oscController;
}

-(void) setOscEnabledForCurrentSession:(BOOL)enabled
{
    _oscEnabled = enabled;

    if (!enabled) {
        @synchronized(_oscController) {
            _oscController.lastButtonFlags = 0;
            _oscController.lastLeftTrigger = 0;
            _oscController.lastRightTrigger = 0;
            _oscController.lastLeftStickX = 0;
            _oscController.lastLeftStickY = 0;
            _oscController.lastRightStickX = 0;
            _oscController.lastRightStickY = 0;
        }
    }
}

+(bool) isSupportedGamepad:(GCController*) controller {
    return controller.extendedGamepad != nil;
}

#pragma clang diagnostic pop

+(int) getGamepadCount {
    int count = 0;
    
    for (GCController* controller in [GCController controllers]) {
        if ([ControllerSupport isSupportedGamepad:controller]) {
            count++;
        }
    }
    
    return count;
}

+(int) getConnectedGamepadMask:(StreamConfiguration*)streamConfig {
    int mask = 0;
    
    if (streamConfig.multiController) {
        int i = 0;
        for (GCController* controller in [GCController controllers]) {
            if ([ControllerSupport isSupportedGamepad:controller]) {
                mask |= 1 << i++;
            }
        }
    }
    else {
        // Some games don't deal with having controller reconnected
        // properly so always report controller 1 if not in MC mode
        mask = 0x1;
    }
    
    return mask;
}

-(NSUInteger) getConnectedGamepadCount
{
    return _controllers.count;
}

-(id) initWithConfig:(StreamConfiguration*)streamConfig delegate:(id<ControllerSupportDelegate>)delegate
{
    self = [super init];
    
    _controllerStreamLock = [[NSLock alloc] init];
    _controllers = [[NSMutableDictionary alloc] init];
    _controllerNumbers = 0;
    _multiController = streamConfig.multiController;
    _swapABXYButtons = streamConfig.swapABXYButtons;
    //陀螺仪
    _motionMode = streamConfig.motionMode;
    
    _delegate = delegate;

    _oscController = [[Controller alloc] init];
    _oscController.playerIndex = 0;

    _oscEnabled = NO;
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings *currentSettings = [dataMan getSettings];
    _rumbleMode = currentSettings.rumbleModeSelection;
    _remoteMouseMode = currentSettings.remoteMouseMode;
    _relativeMouseSensitivityScale = MouseSensitivityScaleForPercentage(currentSettings.relativeMouseSensitivity);
    _longPressStartForGameMenuEnabled = currentSettings.longPressStartForGameMenuEnabled;
    _audioHapticsEnabled = currentSettings.audioHapticsEnabled;
    _audioHapticsOutputTarget = currentSettings.audioHapticsOutputTarget;
    _audioHapticsStrengthScale = MAX(0.25f, MIN((float)currentSettings.audioHapticsStrength / 100.0f, 2.0f));
    _audioHapticsVoiceFilterSelection = currentSettings.audioHapticsVoiceFilterSelection;
    _audioHapticsKeepControllerRumble = currentSettings.audioHapticsKeepControllerRumble;
    
    Log(LOG_I, @"Number of supported controllers connected: %d", [ControllerSupport getGamepadCount]);
    Log(LOG_I, @"Multi-controller: %d", _multiController);
    
    for (GCController* controller in [GCController controllers]) {
        if ([ControllerSupport isSupportedGamepad:controller]) {
            [self assignController:controller];
            [self registerControllerCallbacks:controller];
            
            // Note: We cannot report controller arrival to the host here,
            // because the connection has not been established yet.
        }
    }
    
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        for (GCMouse* mouse in [GCMouse mice]) {
            [self registerMouseCallbacks:mouse];
        }
    }
    
    _controllerConnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        Log(LOG_I, @"Controller connected!");
        
        GCController* controller = note.object;
        
        if (![ControllerSupport isSupportedGamepad:controller]) {
            // Ignore micro gamepads and motion controllers
            return;
        }
        
        Controller* limeController = [self assignController:controller];
        if (limeController) {
            // Register callbacks on the new controller
            [self registerControllerCallbacks:controller];
            
            // Report the controller arrival to the host if we're connected
            [self reportControllerArrival:limeController];
            
            // Notify the delegate
            [self->_delegate gamepadPresenceChanged];
        }
    }];
    _controllerDisconnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidDisconnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        Log(LOG_I, @"Controller disconnected!");
        
        GCController* controller = note.object;
        
        if (![ControllerSupport isSupportedGamepad:controller]) {
            // Ignore micro gamepads and motion controllers
            return;
        }
        
        [self unregisterControllerCallbacks:controller];
        self->_controllerNumbers &= ~(1 << controller.playerIndex);
        Log(LOG_I, @"Unassigning controller index: %ld", (long)controller.playerIndex);
        
        Controller* limeController = [self->_controllers objectForKey:[NSNumber numberWithInteger:controller.playerIndex]];
        if (limeController) {
            // Stop haptics on this controller
            [self cleanupControllerHaptics:limeController];
            
            // Stop motion reports on this controller
            [self cleanupControllerMotion:limeController];
            
            // Stop battery reports on this controller
            [self cleanupControllerBattery:limeController];
            
            // Disassociate this controller from any controllers merged with it
            if (limeController.mergedWithController) {
                assert(limeController.mergedWithController.mergedWithController == limeController);
                limeController.mergedWithController.mergedWithController = nil;
            }
            
            // Inform the server of the updated active gamepads before removing this controller
            [self updateFinished:limeController];
            [self->_controllers removeObjectForKey:[NSNumber numberWithInteger:controller.playerIndex]];
            
            // Notify the delegate
            [self->_delegate gamepadPresenceChanged];
        }
    }];
    
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        _mouseConnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCMouseDidConnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            Log(LOG_I, @"Mouse connected!");
            
            GCMouse* mouse = note.object;
            
            // Register for mouse events
            [self registerMouseCallbacks: mouse];

            // Notify the delegate
            [self->_delegate mousePresenceChanged];
        }];
        _mouseDisconnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCMouseDidDisconnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            Log(LOG_I, @"Mouse disconnected!");
            
            GCMouse* mouse = note.object;
            
            // Unregister for mouse events
            [self unregisterMouseCallbacks: mouse];

            // Notify the delegate
            [self->_delegate mousePresenceChanged];
        }];
        _keyboardConnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCKeyboardDidConnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            Log(LOG_I, @"Keyboard connected!");
        }];
        _keyboardDisconnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCKeyboardDidDisconnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            Log(LOG_I, @"Keyboard disconnected!");
        }];
    }
    
    return self;
}

-(void) connectionEstablished
{
    for (Controller* controller in [_controllers allValues]) {
        // Report the controller arrival to the host if we haven't done so yet
        [self reportControllerArrival:controller];
    }
}

-(void) cleanup
{
    [self stopAudioHaptics];
    [_audioDeviceHaptics cleanup];
    _audioDeviceHaptics = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:_controllerConnectObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_controllerDisconnectObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_mouseConnectObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_mouseDisconnectObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_keyboardConnectObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_keyboardDisconnectObserver];
    
    _controllerConnectObserver = nil;
    _controllerDisconnectObserver = nil;
    _mouseConnectObserver = nil;
    _mouseDisconnectObserver = nil;
    _keyboardConnectObserver = nil;
    _keyboardDisconnectObserver = nil;
    
    _controllerNumbers = 0;
    
    for (Controller* controller in [_controllers allValues]) {
        [controller.menuHoldTimer invalidate];
        controller.menuHoldTimer = nil;
        [self cleanupControllerHaptics:controller];
        [self cleanupControllerMotion:controller];
        [self cleanupControllerBattery:controller];
    }
    [_controllers removeAllObjects];
    
    //陀螺仪
    #if !TARGET_OS_TV
        [self cleanupControllerMotion:_oscController];
        [self cleanupControllerHaptics:_oscController];
        [_oscController.motionManager stopDeviceMotionUpdates];
    #endif
    
    for (GCController* controller in [GCController controllers]) {
        if ([ControllerSupport isSupportedGamepad:controller]) {
            [self unregisterControllerCallbacks:controller];
        }
    }
    
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        for (GCMouse* mouse in [GCMouse mice]) {
            [self unregisterMouseCallbacks:mouse];
        }
    }
}

@end
