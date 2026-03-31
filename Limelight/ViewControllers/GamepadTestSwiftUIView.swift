import UIKit
#if canImport(SwiftUI)
import SwiftUI
import GameController
import CoreHaptics
import CoreMotion
import QuartzCore
import AudioToolbox
import Darwin

private func GamepadLocalized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func GamepadLocalizedFormat(_ key: String, _ args: CVarArg...) -> String {
    String(format: GamepadLocalized(key), locale: Locale.current, arguments: args)
}

@available(iOS 13.0, *)
private struct GamepadTrailPoint: Identifiable {
    let id = UUID()
    let point: CGPoint
    let timestamp: CFTimeInterval
}

@available(iOS 13.0, *)
private enum GamepadTrailStyle {
    static let fadeDelay: CFTimeInterval = 2.0
    static let fadeDuration: CFTimeInterval = 1.0
    static let lifetime: CFTimeInterval = fadeDelay + fadeDuration
    static let minimumSampleInterval: CFTimeInterval = 1.0 / 45.0
    static let minimumDistance: CGFloat = 0.025
    static let opacityBucketCount = 6
}

@available(iOS 13.0, *)
private struct GamepadPollingAnomalyDetail: Identifiable {
    let id = UUID()
    let sampleIndex: Int
    let intervalMs: Double
    let averageMs: Double
    let kind: Kind

    enum Kind {
        case tooFast
        case tooSlow

        var title: String {
            switch self {
            case .tooFast:
                return GamepadLocalized("gamepad.polling.anomaly.fast")
            case .tooSlow:
                return GamepadLocalized("gamepad.polling.anomaly.slow")
            }
        }
    }
}

@available(iOS 13.0, *)
private final class GamepadTestViewModel: NSObject, ObservableObject {
    @Published var controllerName: String = GamepadLocalized("gamepad.status.disconnected")
    @Published var connectionDescription: String = GamepadLocalized("gamepad.status.connect_hint")
    @Published var profileName: String = "Extended Gamepad"
    @Published var playerIndexText: String = GamepadLocalized("gamepad.info.unassigned")
    @Published var deviceModelText: String = GamepadTestViewModel.currentDeviceModelDescription()
    @Published var systemVersionText: String = GamepadTestViewModel.currentSystemVersionDescription()
    @Published var batteryText: String = GamepadLocalized("gamepad.info.unknown")
    @Published var hapticsText: String = GamepadLocalized("gamepad.info.not_detected")
    @Published var connectionTypeText: String = GamepadLocalized("gamepad.connection.unknown")
    @Published var gyroSupportText: String = GamepadLocalized("gamepad.info.not_detected")
    @Published var inferredControllerTypeText: String = GamepadLocalized("gamepad.info.unrecognized")
    @Published var rumbleStatusText: String = GamepadLocalized("gamepad.rumble.tap_to_start")
    @Published var isRumbling = false
    @Published var triggerRumbleEnabled = false
    @Published var pollingStatusText: String = GamepadLocalized("gamepad.polling.tap_to_start")
    @Published var isPollingTestRunning = false
    @Published var pollingProgressText: String = "0 / 1000"
    @Published var pollingHzText: String = "--"
    @Published var pollingMinText: String = "--"
    @Published var pollingMaxText: String = "--"
    @Published var pollingAvgText: String = "--"
    @Published var pollingAnomalyCountText: String = "--"
    @Published var pollingAnomalyDetails: [GamepadPollingAnomalyDetail] = []
    @Published var isShowingPollingAnomalySheet = false
    @Published var showStickTrails = false
    @Published var gyroEnabled = false
    @Published var gyroSourceIndex = 0
    @Published var gyroStatusText: String = GamepadLocalized("gamepad.gyro.device")
    @Published var gyroHintText: String = GamepadLocalized("gamepad.gyro.device_hint")
    @Published var gyroX: Double = 0
    @Published var gyroY: Double = 0
    @Published var gyroZ: Double = 0
    @Published var controllerGyroSupported = false

    @Published var leftStickX: Double = 0
    @Published var leftStickY: Double = 0
    @Published var rightStickX: Double = 0
    @Published var rightStickY: Double = 0
    @Published var leftStickTrailPoints: [GamepadTrailPoint] = []
    @Published var rightStickTrailPoints: [GamepadTrailPoint] = []
    @Published var leftTrigger: Double = 0
    @Published var rightTrigger: Double = 0

    @Published var dpadUp = false
    @Published var dpadDown = false
    @Published var dpadLeft = false
    @Published var dpadRight = false

    @Published var buttonA = false
    @Published var buttonB = false
    @Published var buttonX = false
    @Published var buttonY = false
    @Published var leftShoulder = false
    @Published var rightShoulder = false
    @Published var leftThumbstickButton = false
    @Published var rightThumbstickButton = false
    @Published var menuButton = false
    @Published var optionsButton = false
    @Published var homeButton = false

    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
    private weak var currentController: GCController?
    private var leftHapticEngine: CHHapticEngine?
    private var rightHapticEngine: CHHapticEngine?
    private var leftHapticPlayer: CHHapticPatternPlayer?
    private var rightHapticPlayer: CHHapticPatternPlayer?
    private var leftHapticPlaying = false
    private var rightHapticPlaying = false
    private var fallbackVibrationTimer: Timer?
    private var stickTrailCleanupTimer: Timer?
    private var leftStickPollingTimestamps: [CFTimeInterval] = []
    private var lastPolledLeftStickX: Double = 0
    private var lastPolledLeftStickY: Double = 0
    private var lastLeftStickTrailPoint: GamepadTrailPoint?
    private var lastRightStickTrailPoint: GamepadTrailPoint?
    private let pollingTargetCount = 1000
    private let deviceMotionManager = CMMotionManager()

    override init() {
        super.init()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            self.attachController(notification.object as? GCController)
        }

        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let disconnectedController = notification.object as? GCController else { return }
            if disconnectedController == self.currentController {
                self.currentController = nil
                self.resetState()
                self.attachController(GCController.controllers().first)
            }
        }

        attachController(GCController.controllers().first)
    }

    private func stopMonitoring() {
        if let connectObserver = connectObserver {
            NotificationCenter.default.removeObserver(connectObserver)
        }
        if let disconnectObserver = disconnectObserver {
            NotificationCenter.default.removeObserver(disconnectObserver)
        }
        currentController?.extendedGamepad?.valueChangedHandler = nil
        currentController?.motion?.valueChangedHandler = nil
        stopActiveRumble()
        stopGyroMonitoring()
        stopStickTrailTimer()
    }

    private func attachController(_ controller: GCController?) {
        currentController?.extendedGamepad?.valueChangedHandler = nil
        currentController?.motion?.valueChangedHandler = nil
        currentController = controller

        guard let controller = controller else {
            controllerGyroSupported = false
            resetState()
            configureGyroMonitoring()
            return
        }

        controllerName = controller.vendorName ?? GamepadLocalized("gamepad.status.connected")
        connectionDescription = GamepadLocalized("gamepad.status.press_buttons_hint")
        profileName = controller.extendedGamepad != nil ? "Extended Gamepad" : GamepadLocalized("gamepad.info.basic_profile")
        playerIndexText = playerIndexDescription(for: controller.playerIndex)
        batteryText = batteryDescription(for: controller)
        hapticsText = hapticsDescription(for: controller)
        connectionTypeText = inferredConnectionType(for: controller)
        controllerGyroSupported = controllerSupportsGyro(controller)
        gyroSupportText = controllerGyroSupported ? GamepadLocalized("gamepad.info.gyro_supported") : GamepadLocalized("gamepad.info.unsupported")
        inferredControllerTypeText = inferredControllerType(for: controller)
        stopActiveRumble()
        triggerRumbleEnabled = false
        rumbleStatusText = GamepadLocalized("gamepad.rumble.tap_to_start")
        resetPollingTest(resetResult: true)

        if let gamepad = controller.extendedGamepad {
            gamepad.valueChangedHandler = { [weak self] gamepad, _ in
                self?.update(with: gamepad)
            }
            update(with: gamepad)
        }
        else {
            connectionDescription = GamepadLocalized("gamepad.status.non_extended_warning")
        }

        configureGyroMonitoring()
    }

    private func resetState() {
        controllerName = GamepadLocalized("gamepad.status.disconnected")
        connectionDescription = GamepadLocalized("gamepad.status.connect_hint")
        profileName = "Extended Gamepad"
        playerIndexText = GamepadLocalized("gamepad.info.unassigned")
        deviceModelText = Self.currentDeviceModelDescription()
        systemVersionText = Self.currentSystemVersionDescription()
        batteryText = GamepadLocalized("gamepad.info.unknown")
        hapticsText = GamepadLocalized("gamepad.info.not_detected")
        connectionTypeText = GamepadLocalized("gamepad.connection.unknown")
        gyroSupportText = GamepadLocalized("gamepad.info.not_detected")
        inferredControllerTypeText = GamepadLocalized("gamepad.info.unrecognized")
        rumbleStatusText = GamepadLocalized("gamepad.rumble.tap_to_start")
        isRumbling = false
        triggerRumbleEnabled = false
        resetPollingTest(resetResult: true)
        leftStickX = 0
        leftStickY = 0
        rightStickX = 0
        rightStickY = 0
        leftStickTrailPoints = []
        rightStickTrailPoints = []
        leftTrigger = 0
        rightTrigger = 0
        dpadUp = false
        dpadDown = false
        dpadLeft = false
        dpadRight = false
        buttonA = false
        buttonB = false
        buttonX = false
        buttonY = false
        leftShoulder = false
        rightShoulder = false
        leftThumbstickButton = false
        rightThumbstickButton = false
        menuButton = false
        optionsButton = false
        homeButton = false
        stopActiveRumble()
        gyroStatusText = gyroSourceIndex == 1 ? GamepadLocalized("gamepad.gyro.controller") : GamepadLocalized("gamepad.gyro.device")
        gyroHintText = GamepadLocalized("gamepad.gyro.device_hint")
        gyroX = 0
        gyroY = 0
        gyroZ = 0
        gyroEnabled = false
    }

    private static func currentDeviceModelDescription() -> String {
        let machineIdentifier = currentMachineIdentifier()
        let marketingName = humanReadableDeviceName(for: machineIdentifier)

        guard !machineIdentifier.isEmpty else {
            return UIDevice.current.model
        }

        if marketingName == machineIdentifier {
            return machineIdentifier
        }

        return "\(marketingName) (\(machineIdentifier))"
    }

    private static func currentSystemVersionDescription() -> String {
        let device = UIDevice.current
        return "\(device.systemName) \(device.systemVersion)"
    }

    private static func currentMachineIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = systemInfo.machine

        let rawIdentifier = withUnsafePointer(to: machine) { pointer in
            pointer.withMemoryRebound(
                to: CChar.self,
                capacity: MemoryLayout.size(ofValue: machine)
            ) { reboundPointer in
                String(cString: reboundPointer)
            }
        }

        guard rawIdentifier == "i386" || rawIdentifier == "x86_64" || rawIdentifier == "arm64" else {
            return rawIdentifier
        }

        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? rawIdentifier
    }

    private static func humanReadableDeviceName(for identifier: String) -> String {
        switch identifier {
        case "iPhone10,1", "iPhone10,4":
            return "iPhone 8"
        case "iPhone10,2", "iPhone10,5":
            return "iPhone 8 Plus"
        case "iPhone10,3", "iPhone10,6":
            return "iPhone X"
        case "iPhone11,2":
            return "iPhone XS"
        case "iPhone11,4", "iPhone11,6":
            return "iPhone XS Max"
        case "iPhone11,8":
            return "iPhone XR"
        case "iPhone12,1":
            return "iPhone 11"
        case "iPhone12,3":
            return "iPhone 11 Pro"
        case "iPhone12,5":
            return "iPhone 11 Pro Max"
        case "iPhone12,8":
            return "iPhone SE (2nd generation)"
        case "iPhone13,1":
            return "iPhone 12 mini"
        case "iPhone13,2":
            return "iPhone 12"
        case "iPhone13,3":
            return "iPhone 12 Pro"
        case "iPhone13,4":
            return "iPhone 12 Pro Max"
        case "iPhone14,4":
            return "iPhone 13 mini"
        case "iPhone14,5":
            return "iPhone 13"
        case "iPhone14,2":
            return "iPhone 13 Pro"
        case "iPhone14,3":
            return "iPhone 13 Pro Max"
        case "iPhone14,6":
            return "iPhone SE (3rd generation)"
        case "iPhone14,7":
            return "iPhone 14"
        case "iPhone14,8":
            return "iPhone 14 Plus"
        case "iPhone15,2":
            return "iPhone 14 Pro"
        case "iPhone15,3":
            return "iPhone 14 Pro Max"
        case "iPhone15,4":
            return "iPhone 15"
        case "iPhone15,5":
            return "iPhone 15 Plus"
        case "iPhone16,1":
            return "iPhone 15 Pro"
        case "iPhone16,2":
            return "iPhone 15 Pro Max"
        case "iPhone17,3":
            return "iPhone 16"
        case "iPhone17,4":
            return "iPhone 16 Plus"
        case "iPhone17,1":
            return "iPhone 16 Pro"
        case "iPhone17,2":
            return "iPhone 16 Pro Max"
        case "iPad11,6", "iPad11,7":
            return "iPad (8th generation)"
        case "iPad12,1", "iPad12,2":
            return "iPad (9th generation)"
        case "iPad13,18", "iPad13,19":
            return "iPad (10th generation)"
        case "iPad14,8", "iPad14,9":
            return "iPad Air (11-inch) (M2)"
        case "iPad14,10", "iPad14,11":
            return "iPad Air (13-inch) (M2)"
        case "iPad13,1", "iPad13,2":
            return "iPad Air (4th generation)"
        case "iPad13,16", "iPad13,17":
            return "iPad Air (5th generation)"
        case "iPad14,1", "iPad14,2":
            return "iPad mini (6th generation)"
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4":
            return "iPad Pro (11-inch)"
        case "iPad8,9", "iPad8,10":
            return "iPad Pro (11-inch) (2nd generation)"
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7":
            return "iPad Pro (11-inch) (3rd generation)"
        case "iPad14,3", "iPad14,4":
            return "iPad Pro (11-inch) (4th generation)"
        case "iPad16,3", "iPad16,4":
            return "iPad Pro (11-inch) (M4)"
        case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8":
            return "iPad Pro (12.9-inch) (3rd generation)"
        case "iPad8,11", "iPad8,12":
            return "iPad Pro (12.9-inch) (4th generation)"
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11":
            return "iPad Pro (12.9-inch) (5th generation)"
        case "iPad14,5", "iPad14,6":
            return "iPad Pro (12.9-inch) (6th generation)"
        case "iPad16,5", "iPad16,6":
            return "iPad Pro (13-inch) (M4)"
        case "iPod9,1":
            return "iPod touch (7th generation)"
        default:
            return identifier
        }
    }

    private func controllerSupportsGyro(_ controller: GCController?) -> Bool {
        guard let motion = controller?.motion else { return false }
        if #available(iOS 14.0, *) {
            return motion.hasRotationRate
        }
        return true
    }

    private func stopGyroMonitoring() {
        deviceMotionManager.stopGyroUpdates()
        if #available(iOS 14.0, *) {
            if let motion = currentController?.motion, motion.sensorsRequireManualActivation {
                motion.sensorsActive = false
            }
        }
        currentController?.motion?.valueChangedHandler = nil
    }

    private func configureGyroMonitoring() {
        stopGyroMonitoring()
        guard gyroEnabled else {
            gyroStatusText = gyroSourceIndex == 1 ? GamepadLocalized("gamepad.gyro.controller") : GamepadLocalized("gamepad.gyro.device")
            gyroHintText = GamepadLocalized("gamepad.gyro.enable_hint")
            gyroX = 0
            gyroY = 0
            gyroZ = 0
            return
        }
        if gyroSourceIndex == 1 {
            startControllerGyroMonitoring()
        }
        else {
            startDeviceGyroMonitoring()
        }
    }

    func setGyroEnabled(_ enabled: Bool) {
        gyroEnabled = enabled
        configureGyroMonitoring()
    }

    func setGyroSourceIndex(_ newValue: Int) {
        gyroSourceIndex = newValue
        configureGyroMonitoring()
    }

    func setShowStickTrails(_ enabled: Bool) {
        showStickTrails = enabled
        enabled ? startStickTrailTimer() : stopStickTrailTimer()
        if !enabled {
            clearStickTrails()
        }
    }

    private func appendStickTrailPoint(_ point: CGPoint, toLeftStick: Bool) {
        pruneStaleStickTrailPoints()
        let normalizedPoint = CGPoint(
            x: CGFloat(min(max(point.x, -1), 1)),
            y: CGFloat(min(max(point.y, -1), 1))
        )
        let trailPoint = GamepadTrailPoint(point: normalizedPoint, timestamp: CACurrentMediaTime())
        let previousPoint = toLeftStick ? lastLeftStickTrailPoint : lastRightStickTrailPoint

        guard shouldAppendTrailPoint(trailPoint, previousPoint: previousPoint) else {
            return
        }

        if toLeftStick {
            leftStickTrailPoints.append(trailPoint)
            lastLeftStickTrailPoint = trailPoint
        }
        else {
            rightStickTrailPoints.append(trailPoint)
            lastRightStickTrailPoint = trailPoint
        }
    }

    private func clearStickTrails() {
        leftStickTrailPoints = []
        rightStickTrailPoints = []
        lastLeftStickTrailPoint = nil
        lastRightStickTrailPoint = nil
    }

    private func startStickTrailTimer() {
        guard stickTrailCleanupTimer == nil else { return }
        stickTrailCleanupTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            self?.pruneStaleStickTrailPoints()
        }
    }

    private func stopStickTrailTimer() {
        stickTrailCleanupTimer?.invalidate()
        stickTrailCleanupTimer = nil
    }

    private func pruneStaleStickTrailPoints() {
        let threshold = CACurrentMediaTime() - GamepadTrailStyle.lifetime
        leftStickTrailPoints.removeAll { $0.timestamp < threshold }
        rightStickTrailPoints.removeAll { $0.timestamp < threshold }
        lastLeftStickTrailPoint = leftStickTrailPoints.last
        lastRightStickTrailPoint = rightStickTrailPoints.last
    }

    private func shouldAppendTrailPoint(_ point: GamepadTrailPoint, previousPoint: GamepadTrailPoint?) -> Bool {
        guard let previousPoint else {
            return true
        }

        let elapsed = point.timestamp - previousPoint.timestamp
        let deltaX = point.point.x - previousPoint.point.x
        let deltaY = point.point.y - previousPoint.point.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

        return elapsed >= GamepadTrailStyle.minimumSampleInterval || distance >= GamepadTrailStyle.minimumDistance
    }

    private func startDeviceGyroMonitoring() {
        gyroStatusText = GamepadLocalized("gamepad.gyro.device")

        guard deviceMotionManager.isGyroAvailable else {
            gyroHintText = GamepadLocalized("gamepad.gyro.device_unsupported")
            gyroX = 0
            gyroY = 0
            gyroZ = 0
            return
        }

        gyroHintText = GamepadLocalized("gamepad.gyro.device_hint")
        deviceMotionManager.gyroUpdateInterval = 1.0 / 60.0
        deviceMotionManager.startGyroUpdates(to: .main) { [weak self] data, _ in
            guard let self, let rotationRate = data?.rotationRate else { return }
            self.gyroX = rotationRate.x
            self.gyroY = rotationRate.y
            self.gyroZ = rotationRate.z
        }
    }

    private func startControllerGyroMonitoring() {
        gyroStatusText = GamepadLocalized("gamepad.gyro.controller")

        guard let motion = currentController?.motion, controllerSupportsGyro(currentController) else {
            gyroHintText = GamepadLocalized("gamepad.gyro.controller_unsupported")
            gyroX = 0
            gyroY = 0
            gyroZ = 0
            return
        }

        gyroHintText = GamepadLocalized("gamepad.gyro.controller_hint")

        if #available(iOS 14.0, *) {
            if motion.sensorsRequireManualActivation {
                motion.sensorsActive = true
            }
        }

        let applyMotion: (GCMotion) -> Void = { [weak self] motion in
            guard let self else { return }
            let rotationRate = motion.rotationRate
            DispatchQueue.main.async {
                self.gyroX = Double(rotationRate.x)
                self.gyroY = Double(rotationRate.y)
                self.gyroZ = Double(rotationRate.z)
            }
        }

        motion.valueChangedHandler = applyMotion
        applyMotion(motion)
    }

    private func resetPollingTest(resetResult: Bool) {
        isPollingTestRunning = false
        leftStickPollingTimestamps.removeAll()
        pollingProgressText = "0 / \(pollingTargetCount)"
        pollingStatusText = GamepadLocalized("gamepad.polling.tap_to_start")
        pollingAnomalyDetails = []
        isShowingPollingAnomalySheet = false
        lastPolledLeftStickX = leftStickX
        lastPolledLeftStickY = leftStickY

        if resetResult {
            pollingHzText = "--"
            pollingMinText = "--"
            pollingMaxText = "--"
            pollingAvgText = "--"
            pollingAnomalyCountText = "--"
        }
    }

    private func playerIndexDescription(for playerIndex: GCControllerPlayerIndex) -> String {
        switch playerIndex {
        case .indexUnset:
            return GamepadLocalized("gamepad.info.unassigned")
        case .index1:
            return "Player 1"
        case .index2:
            return "Player 2"
        case .index3:
            return "Player 3"
        case .index4:
            return "Player 4"
        @unknown default:
            return GamepadLocalized("gamepad.info.unknown")
        }
    }

    private func batteryDescription(for controller: GCController) -> String {
        if #available(iOS 14.0, *), let battery = controller.battery {
            let level = Int((battery.batteryLevel * 100).rounded())
            switch battery.batteryState {
            case .charging:
                return GamepadLocalizedFormat("gamepad.battery.charging", level)
            case .discharging:
                return "\(level)%"
            case .full:
                return GamepadLocalized("gamepad.battery.full")
            case .unknown:
                return GamepadLocalized("gamepad.info.unknown")
            @unknown default:
                return GamepadLocalized("gamepad.info.unknown")
            }
        }

        return GamepadLocalized("gamepad.info.unsupported")
    }

    private func hapticsDescription(for controller: GCController) -> String {
        if #available(iOS 14.0, *), let haptics = controller.haptics {
            let localities = haptics.supportedLocalities
            if localities.contains(GCHapticsLocality.rightHandle) || localities.contains(GCHapticsLocality.leftHandle) {
                return GamepadLocalized("gamepad.haptics.supported")
            }
            return GamepadLocalized("gamepad.haptics.limited")
        }

        return GamepadLocalized("gamepad.info.unsupported")
    }

    private func inferredControllerType(for controller: GCController) -> String {
        let vendor = (controller.vendorName ?? "").lowercased()

        if vendor.contains("xbox") {
            return GamepadLocalized("gamepad.type.xbox")
        }
        if vendor.contains("dualsense") || vendor.contains("wireless controller") || vendor.contains("dualshock") || vendor.contains("playstation") || vendor.contains("ps5") || vendor.contains("ps4") {
            return GamepadLocalized("gamepad.type.playstation")
        }
        if vendor.contains("switch") || vendor.contains("joy-con") || vendor.contains("pro controller") {
            return GamepadLocalized("gamepad.type.switch")
        }
        if vendor.contains("8bitdo") {
            return GamepadLocalized("gamepad.type.8bitdo")
        }
        if vendor.contains("gamesir") {
            return GamepadLocalized("gamepad.type.gamesir")
        }
        if vendor.contains("razer") {
            return GamepadLocalized("gamepad.type.razer")
        }
        if controller.extendedGamepad != nil {
            return GamepadLocalized("gamepad.type.generic_extended")
        }
        return GamepadLocalized("gamepad.type.generic")
    }

    private func inferredConnectionType(for controller: GCController) -> String {
        if controller.isAttachedToDevice {
            return GamepadLocalized("gamepad.connection.attached")
        }
        return GamepadLocalized("gamepad.connection.external")
    }

    private func stopActiveRumble() {
        try? leftHapticPlayer?.stop(atTime: 0)
        try? rightHapticPlayer?.stop(atTime: 0)
        leftHapticPlayer = nil
        rightHapticPlayer = nil
        leftHapticEngine?.stop(completionHandler: nil)
        rightHapticEngine?.stop(completionHandler: nil)
        leftHapticEngine = nil
        rightHapticEngine = nil
        leftHapticPlaying = false
        rightHapticPlaying = false
        fallbackVibrationTimer?.invalidate()
        fallbackVibrationTimer = nil
        refreshRumbleState()
    }

    private func startContinuousDeviceVibration() {
        fallbackVibrationTimer?.invalidate()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        fallbackVibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        refreshRumbleState()
    }

    @available(iOS 14.0, *)
    private func stopRumble(for locality: GCHapticsLocality) {
        if locality == .leftHandle {
            try? leftHapticPlayer?.stop(atTime: 0)
            leftHapticPlayer = nil
            leftHapticEngine?.stop(completionHandler: nil)
            leftHapticEngine = nil
            leftHapticPlaying = false
        }
        else if locality == .rightHandle {
            try? rightHapticPlayer?.stop(atTime: 0)
            rightHapticPlayer = nil
            rightHapticEngine?.stop(completionHandler: nil)
            rightHapticEngine = nil
            rightHapticPlaying = false
        }
    }

    private func refreshRumbleState() {
        isRumbling = leftHapticPlayer != nil || rightHapticPlayer != nil || fallbackVibrationTimer != nil
    }

    @available(iOS 14.0, *)
    private func normalizedTriggerIntensity(_ value: Double) -> Float {
        let deadZone = 0.08
        guard value > deadZone else {
            return 0
        }

        let normalized = (value - deadZone) / (1.0 - deadZone)
        return Float(min(max(normalized, 0), 1))
    }

    @available(iOS 14.0, *)
    private func setContinuousRumbleIntensity(_ intensity: Float, for locality: GCHapticsLocality) -> Bool {
        let clampedIntensity = min(max(intensity, 0), 1)

        guard let controller = currentController, let haptics = controller.haptics else {
            return false
        }
        guard haptics.supportedLocalities.contains(locality) else {
            return false
        }

        if clampedIntensity <= 0.001 {
            stopRumble(for: locality)
            refreshRumbleState()
            return true
        }

        do {
            let engine: CHHapticEngine
            let player: CHHapticPatternPlayer

            switch locality {
            case .leftHandle:
                if let existingEngine = leftHapticEngine, let existingPlayer = leftHapticPlayer {
                    engine = existingEngine
                    player = existingPlayer
                }
                else {
                    guard let newEngine = haptics.createEngine(withLocality: locality) else {
                        return false
                    }
                    try newEngine.start()
                    let baseIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                    let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
                    let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [baseIntensity, sharpness], relativeTime: 0, duration: 60)
                    let pattern = try CHHapticPattern(events: [event], parameters: [])
                    let newPlayer = try newEngine.makePlayer(with: pattern)
                    leftHapticEngine = newEngine
                    leftHapticPlayer = newPlayer
                    leftHapticPlaying = false
                    engine = newEngine
                    player = newPlayer
                }
            case .rightHandle:
                if let existingEngine = rightHapticEngine, let existingPlayer = rightHapticPlayer {
                    engine = existingEngine
                    player = existingPlayer
                }
                else {
                    guard let newEngine = haptics.createEngine(withLocality: locality) else {
                        return false
                    }
                    try newEngine.start()
                    let baseIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                    let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
                    let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [baseIntensity, sharpness], relativeTime: 0, duration: 60)
                    let pattern = try CHHapticPattern(events: [event], parameters: [])
                    let newPlayer = try newEngine.makePlayer(with: pattern)
                    rightHapticEngine = newEngine
                    rightHapticPlayer = newPlayer
                    rightHapticPlaying = false
                    engine = newEngine
                    player = newPlayer
                }
            default:
                return false
            }

            let dynamicIntensity = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: clampedIntensity, relativeTime: 0)
            try player.sendParameters([dynamicIntensity], atTime: CHHapticTimeImmediate)
            if locality == .leftHandle {
                if leftHapticPlaying == false {
                    try player.start(atTime: 0)
                    leftHapticPlaying = true
                }
            }
            else if locality == .rightHandle {
                if rightHapticPlaying == false {
                    try player.start(atTime: 0)
                    rightHapticPlaying = true
                }
            }
            refreshRumbleState()
            return true
        }
        catch {
            stopRumble(for: locality)
            refreshRumbleState()
            return false
        }
    }

    @available(iOS 14.0, *)
    private func startContinuousRumble(for localities: [GCHapticsLocality], intensity: Float = 0.75) -> Bool {
        var startedAny = false
        for locality in localities {
            if setContinuousRumbleIntensity(intensity, for: locality) {
                startedAny = true
            }
        }

        if startedAny {
            return true
        }

        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
        return false
    }

    @available(iOS 14.0, *)
    private func syncTriggerDrivenRumble() {
        guard triggerRumbleEnabled else { return }
        let leftIntensity = normalizedTriggerIntensity(leftTrigger)
        let rightIntensity = normalizedTriggerIntensity(rightTrigger)

        if leftIntensity <= 0.001 && rightIntensity <= 0.001 {
            stopRumble(for: .leftHandle)
            stopRumble(for: .rightHandle)
            refreshRumbleState()
            rumbleStatusText = GamepadLocalized("gamepad.rumble.trigger_enabled")
            return
        }

        let leftUpdated = setContinuousRumbleIntensity(leftIntensity, for: .leftHandle)
        let rightUpdated = setContinuousRumbleIntensity(rightIntensity, for: .rightHandle)

        if leftUpdated || rightUpdated {
            rumbleStatusText = GamepadLocalized("gamepad.rumble.trigger_running")
        }
        else {
            stopActiveRumble()
            rumbleStatusText = GamepadLocalized("gamepad.rumble.continuous_unsupported")
            triggerRumbleEnabled = false
        }
    }

    func toggleManualRumble() {
        triggerRumbleEnabled = false
        if isRumbling {
            stopActiveRumble()
            rumbleStatusText = GamepadLocalized("gamepad.rumble.stopped")
            return
        }

        if #available(iOS 14.0, *), startContinuousRumble(for: [.leftHandle, .rightHandle]) {
            rumbleStatusText = GamepadLocalized("gamepad.rumble.running")
        }
        else {
            startContinuousDeviceVibration()
            rumbleStatusText = GamepadLocalized("gamepad.rumble.fallback_device")
        }
    }

    func setTriggerRumbleEnabled(_ enabled: Bool) {
        triggerRumbleEnabled = enabled
        if !enabled {
            if isRumbling {
                stopActiveRumble()
            }
            rumbleStatusText = GamepadLocalized("gamepad.rumble.tap_to_start")
            return
        }

        if #available(iOS 14.0, *) {
            syncTriggerDrivenRumble()
            if !isRumbling {
                rumbleStatusText = GamepadLocalized("gamepad.rumble.after_trigger")
            }
        }
        else {
            triggerRumbleEnabled = false
            rumbleStatusText = GamepadLocalized("gamepad.rumble.system_unsupported")
        }
    }

    func togglePollingTest() {
        if isPollingTestRunning {
            resetPollingTest(resetResult: false)
            pollingStatusText = GamepadLocalized("gamepad.polling.stopped")
            return
        }

        leftStickPollingTimestamps.removeAll()
        isPollingTestRunning = true
        pollingStatusText = pollingRunningStatusText(currentIntervalMs: nil)
        pollingProgressText = "0 / \(pollingTargetCount)"
        pollingHzText = "--"
        pollingMinText = "--"
        pollingMaxText = "--"
        pollingAvgText = "--"
        pollingAnomalyCountText = "--"
        pollingAnomalyDetails = []
        isShowingPollingAnomalySheet = false
        lastPolledLeftStickX = leftStickX
        lastPolledLeftStickY = leftStickY
    }

    private func recordLeftStickPollingSample(x: Double, y: Double) {
        guard isPollingTestRunning else { return }

        let deltaX = abs(x - lastPolledLeftStickX)
        let deltaY = abs(y - lastPolledLeftStickY)
        guard deltaX > 0.0005 || deltaY > 0.0005 else { return }

        lastPolledLeftStickX = x
        lastPolledLeftStickY = y
        let timestamp = CACurrentMediaTime()
        leftStickPollingTimestamps.append(timestamp)
        pollingProgressText = "\(leftStickPollingTimestamps.count) / \(pollingTargetCount)"

        if leftStickPollingTimestamps.count > 1 {
            let previousTimestamp = leftStickPollingTimestamps[leftStickPollingTimestamps.count - 2]
            pollingStatusText = pollingRunningStatusText(currentIntervalMs: (timestamp - previousTimestamp) * 1000)
        }

        guard leftStickPollingTimestamps.count >= pollingTargetCount else { return }
        finalizePollingTest()
    }

    private func pollingRunningStatusText(currentIntervalMs: Double?) -> String {
        guard let currentIntervalMs = currentIntervalMs else {
            return GamepadLocalized("gamepad.polling.running_pending")
        }

        return GamepadLocalizedFormat("gamepad.polling.running", currentIntervalMs)
    }

    private func finalizePollingTest() {
        isPollingTestRunning = false

        let intervals = zip(leftStickPollingTimestamps.dropFirst(), leftStickPollingTimestamps.dropLast()).map { current, previous in
            current - previous
        }.filter { $0 > 0 }

        guard !intervals.isEmpty else {
            pollingStatusText = GamepadLocalized("gamepad.polling.insufficient_data")
            pollingHzText = "--"
            pollingMinText = "--"
            pollingMaxText = "--"
            pollingAvgText = "--"
            pollingAnomalyCountText = "--"
            pollingAnomalyDetails = []
            return
        }

        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        let minimumInterval = intervals.min() ?? averageInterval
        let maximumInterval = intervals.max() ?? averageInterval
        let anomalyDetails = intervals.enumerated().compactMap { offset, interval -> GamepadPollingAnomalyDetail? in
            if interval > averageInterval * 2.5 {
                return GamepadPollingAnomalyDetail(
                    sampleIndex: offset + 2,
                    intervalMs: interval * 1000,
                    averageMs: averageInterval * 1000,
                    kind: .tooSlow
                )
            }
            if interval < averageInterval * 0.4 {
                return GamepadPollingAnomalyDetail(
                    sampleIndex: offset + 2,
                    intervalMs: interval * 1000,
                    averageMs: averageInterval * 1000,
                    kind: .tooFast
                )
            }
            return nil
        }
        let hz = averageInterval > 0 ? 1.0 / averageInterval : 0

        pollingStatusText = GamepadLocalized("gamepad.polling.completed")
        pollingHzText = String(format: "%.1f Hz", hz)
        pollingMinText = String(format: "%.2f ms", minimumInterval * 1000)
        pollingMaxText = String(format: "%.2f ms", maximumInterval * 1000)
        pollingAvgText = String(format: "%.2f ms", averageInterval * 1000)
        pollingAnomalyCountText = "\(anomalyDetails.count)"
        pollingAnomalyDetails = anomalyDetails
    }

    func presentPollingAnomalySheet() {
        guard !pollingAnomalyDetails.isEmpty else { return }
        isShowingPollingAnomalySheet = true
    }

    private func update(with gamepad: GCExtendedGamepad) {
        DispatchQueue.main.async {
            guard let controller = gamepad.controller else { return }

            self.playerIndexText = self.playerIndexDescription(for: controller.playerIndex)
            self.batteryText = self.batteryDescription(for: controller)
            self.hapticsText = self.hapticsDescription(for: controller)
            self.connectionTypeText = self.inferredConnectionType(for: controller)
            self.gyroSupportText = self.controllerSupportsGyro(controller) ? GamepadLocalized("gamepad.info.gyro_supported") : GamepadLocalized("gamepad.info.unsupported")
            self.inferredControllerTypeText = self.inferredControllerType(for: controller)

            self.leftStickX = Double(gamepad.leftThumbstick.xAxis.value)
            self.leftStickY = Double(-gamepad.leftThumbstick.yAxis.value)
            self.rightStickX = Double(gamepad.rightThumbstick.xAxis.value)
            self.rightStickY = Double(-gamepad.rightThumbstick.yAxis.value)
            if self.showStickTrails {
                self.appendStickTrailPoint(CGPoint(x: self.leftStickX, y: self.leftStickY), toLeftStick: true)
                self.appendStickTrailPoint(CGPoint(x: self.rightStickX, y: self.rightStickY), toLeftStick: false)
            }
            self.recordLeftStickPollingSample(x: self.leftStickX, y: self.leftStickY)
            self.leftTrigger = Double(gamepad.leftTrigger.value)
            self.rightTrigger = Double(gamepad.rightTrigger.value)

            self.dpadUp = gamepad.dpad.up.isPressed
            self.dpadDown = gamepad.dpad.down.isPressed
            self.dpadLeft = gamepad.dpad.left.isPressed
            self.dpadRight = gamepad.dpad.right.isPressed

            self.buttonA = gamepad.buttonA.isPressed
            self.buttonB = gamepad.buttonB.isPressed
            self.buttonX = gamepad.buttonX.isPressed
            self.buttonY = gamepad.buttonY.isPressed
            self.leftShoulder = gamepad.leftShoulder.isPressed
            self.rightShoulder = gamepad.rightShoulder.isPressed
            self.leftThumbstickButton = gamepad.leftThumbstickButton?.isPressed ?? false
            self.rightThumbstickButton = gamepad.rightThumbstickButton?.isPressed ?? false
            self.optionsButton = gamepad.buttonOptions?.isPressed ?? false
            self.menuButton = gamepad.buttonMenu.isPressed

            if #available(iOS 14.0, *) {
                self.homeButton = gamepad.buttonHome?.isPressed ?? false
            }
            else {
                self.homeButton = false
            }

            if #available(iOS 14.0, *) {
                self.syncTriggerDrivenRumble()
            }
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadTestBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    colorScheme == .dark ? Color(red: 0.08, green: 0.08, blue: 0.12) : Color(red: 0.97, green: 0.95, blue: 1.0),
                    colorScheme == .dark ? Color(red: 0.10, green: 0.09, blue: 0.16) : Color(red: 0.95, green: 0.93, blue: 1.0),
                    colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.10) : Color(red: 0.94, green: 0.92, blue: 0.98)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(colorScheme == .dark ? Color(red: 0.46, green: 0.31, blue: 0.82).opacity(0.18) : Color(red: 0.72, green: 0.61, blue: 1.0).opacity(0.24))
                .frame(width: 260, height: 260)
                .blur(radius: 20)
                .offset(x: 120, y: -200)

            Circle()
                .fill(colorScheme == .dark ? Color(red: 0.18, green: 0.56, blue: 0.82).opacity(0.14) : Color(red: 0.58, green: 0.77, blue: 1.0).opacity(0.18))
                .frame(width: 210, height: 210)
                .blur(radius: 24)
                .offset(x: -140, y: 290)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

@available(iOS 13.0, *)
private struct GamepadCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.80))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.68), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.05), radius: 14, x: 0, y: 8)
    }
}

@available(iOS 13.0, *)
private struct GamepadStatusCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String

    var body: some View {
        GamepadCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.96) : Color(red: 0.27, green: 0.20, blue: 0.40))

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.68) : Color(red: 0.42, green: 0.35, blue: 0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadInfoRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.72) : Color(red: 0.36, green: 0.29, blue: 0.50))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.94) : Color(red: 0.26, green: 0.21, blue: 0.39))
                .multilineTextAlignment(.trailing)
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadDeviceInfoCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let vendor: String
    let profile: String
    let playerIndex: String
    let battery: String
    let haptics: String
    let connectionType: String
    let gyroSupport: String
    let inferredControllerType: String

    var body: some View {
        GamepadCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(GamepadLocalized("gamepad.card.device_info"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.94) : Color(red: 0.29, green: 0.22, blue: 0.42))

                GamepadInfoRow(title: GamepadLocalized("gamepad.info.name"), value: vendor)
                GamepadInfoRow(title: GamepadLocalized("gamepad.info.profile"), value: profile)
                GamepadInfoRow(title: GamepadLocalized("gamepad.info.player"), value: playerIndex)
                GamepadInfoRow(title: GamepadLocalized("gamepad.info.connection"), value: connectionType)
                GamepadInfoRow(title: GamepadLocalized("gamepad.info.battery"), value: battery)
                GamepadInfoRow(title: GamepadLocalized("gamepad.info.haptics"), value: haptics)
                GamepadInfoRow(title: GamepadLocalized("gamepad.info.gyro"), value: gyroSupport)
                GamepadInfoRow(title: GamepadLocalized("gamepad.info.type"), value: inferredControllerType)
            }
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadCurrentDeviceCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let deviceModel: String
    let systemVersion: String

    var body: some View {
        GamepadCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(GamepadLocalized("gamepad.card.current_device"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.94) : Color(red: 0.29, green: 0.22, blue: 0.42))

                GamepadInfoRow(title: GamepadLocalized("gamepad.info.device_model"), value: deviceModel)
                GamepadInfoRow(title: GamepadLocalized("gamepad.info.system_version"), value: systemVersion)
            }
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadRumbleTestCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let statusText: String
    let isRumbling: Bool
    let triggerRumbleEnabled: Bool
    let onTrigger: () -> Void
    let onTriggerModeChanged: (Bool) -> Void

    var body: some View {
        GamepadCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(GamepadLocalized("gamepad.card.rumble_test"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.94) : Color(red: 0.29, green: 0.22, blue: 0.42))

                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.68) : Color(red: 0.43, green: 0.35, blue: 0.60))

                Button(action: onTrigger) {
                    HStack(spacing: 10) {
                        Image(systemName: "wave.3.right.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(isRumbling ? GamepadLocalized("gamepad.rumble.stop") : GamepadLocalized("gamepad.rumble.start"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isRumbling ? Color(red: 0.78, green: 0.34, blue: 0.47) : Color(red: 0.55, green: 0.51, blue: 0.93))
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Toggle(isOn: Binding(get: {
                    triggerRumbleEnabled
                }, set: { newValue in
                    onTriggerModeChanged(newValue)
                })) {
                    Text(GamepadLocalized("gamepad.rumble.after_trigger_toggle"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.88) : Color(red: 0.29, green: 0.22, blue: 0.42))
                }
            }
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadGyroMeterRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        let clampedValue = min(max(value, -3.0), 3.0)
        let normalizedOffset = CGFloat(clampedValue / 3.0)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.72) : Color(red: 0.36, green: 0.29, blue: 0.50))
                Spacer(minLength: 8)
                Text(String(format: "%.2f rad/s", value))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.64) : Color(red: 0.45, green: 0.38, blue: 0.60))
            }

            GeometryReader { proxy in
                let trackWidth = proxy.size.width
                let dotSize: CGFloat = 16
                let centerX = trackWidth / 2
                let maxOffset = max(0, (trackWidth - dotSize) / 2)

                ZStack {
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.72))

                    Capsule()
                        .fill(tint.opacity(0.18))
                        .padding(.vertical, 2)

                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.95))
                        .frame(width: 1, height: 14)

                    Circle()
                        .fill(tint)
                        .frame(width: dotSize, height: dotSize)
                        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
                        .position(
                            x: centerX + normalizedOffset * maxOffset,
                            y: proxy.size.height / 2
                        )
                }
            }
            .frame(height: 18)
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadGyroTestCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let isEnabled: Bool
    let selectedSourceIndex: Int
    let controllerGyroSupported: Bool
    let statusText: String
    let hintText: String
    let x: Double
    let y: Double
    let z: Double
    let onEnabledChanged: (Bool) -> Void
    let onSourceChanged: (Int) -> Void

    var body: some View {
        GamepadCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(GamepadLocalized("gamepad.card.gyro_test"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.94) : Color(red: 0.29, green: 0.22, blue: 0.42))

                Toggle(isOn: Binding(get: {
                    isEnabled
                }, set: { newValue in
                    onEnabledChanged(newValue)
                })) {
                    Text(GamepadLocalized("gamepad.gyro.enable_toggle"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.88) : Color(red: 0.29, green: 0.22, blue: 0.42))
                }

                Picker("", selection: Binding(get: {
                    selectedSourceIndex
                }, set: { newValue in
                    onSourceChanged(newValue)
                })) {
                    Text(GamepadLocalized("gamepad.gyro.device")).tag(0)
                    Text(GamepadLocalized("gamepad.gyro.controller")).tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())

                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.88) : Color(red: 0.29, green: 0.22, blue: 0.42))

                Text(controllerGyroSupported || selectedSourceIndex == 0 ? hintText : GamepadLocalized("gamepad.gyro.controller_unsupported"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.68) : Color(red: 0.43, green: 0.35, blue: 0.60))

                if isEnabled {
                    GamepadGyroMeterRow(
                        title: GamepadLocalized("gamepad.gyro.axis_x"),
                        value: x,
                        tint: Color(red: 0.46, green: 0.52, blue: 0.95)
                    )
                    GamepadGyroMeterRow(
                        title: GamepadLocalized("gamepad.gyro.axis_y"),
                        value: y,
                        tint: Color(red: 0.39, green: 0.78, blue: 0.69)
                    )
                    GamepadGyroMeterRow(
                        title: GamepadLocalized("gamepad.gyro.axis_z"),
                        value: z,
                        tint: Color(red: 0.93, green: 0.65, blue: 0.24)
                    )
                }
            }
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadPollingStatRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    var isInteractive: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.72) : Color(red: 0.36, green: 0.29, blue: 0.50))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isInteractive ? (colorScheme == .dark ? Color(red: 0.78, green: 0.70, blue: 1.0) : Color(red: 0.46, green: 0.34, blue: 0.78)) : (colorScheme == .dark ? Color.white.opacity(0.94) : Color(red: 0.26, green: 0.21, blue: 0.39)))
            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.44) : Color(red: 0.56, green: 0.49, blue: 0.75))
            }
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadPollingTestCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let statusText: String
    let progressText: String
    let hzText: String
    let minText: String
    let maxText: String
    let avgText: String
    let anomalyCountText: String
    let hasAnomalyDetails: Bool
    let isRunning: Bool
    let onShowAnomalies: () -> Void
    let onTrigger: () -> Void

    var body: some View {
        GamepadCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(GamepadLocalized("gamepad.card.polling_test"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.94) : Color(red: 0.29, green: 0.22, blue: 0.42))

                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.68) : Color(red: 0.43, green: 0.35, blue: 0.60))

                VStack(spacing: 4) {
                    Text(GamepadLocalized("gamepad.polling.rate"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.64) : Color(red: 0.43, green: 0.35, blue: 0.60))

                    Text(hzText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? Color(red: 0.90, green: 0.85, blue: 1.0) : Color(red: 0.30, green: 0.21, blue: 0.54))
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.62))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.80), lineWidth: 1)
                )

                GamepadPollingStatRow(title: GamepadLocalized("gamepad.polling.progress"), value: progressText)
                GamepadPollingStatRow(title: GamepadLocalized("gamepad.polling.min"), value: minText)
                GamepadPollingStatRow(title: GamepadLocalized("gamepad.polling.max"), value: maxText)
                GamepadPollingStatRow(title: GamepadLocalized("gamepad.polling.avg"), value: avgText)
                GamepadPollingStatRow(title: GamepadLocalized("gamepad.polling.anomaly_count"),
                                      value: anomalyCountText,
                                      isInteractive: hasAnomalyDetails,
                                      action: hasAnomalyDetails ? onShowAnomalies : nil)

                Text(GamepadLocalized("gamepad.polling.anomaly_hint"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.64) : Color(red: 0.43, green: 0.35, blue: 0.60))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onTrigger) {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.path.ecg.rectangle")
                            .font(.system(size: 18, weight: .semibold))
                        Text(isRunning ? GamepadLocalized("gamepad.polling.stop") : GamepadLocalized("gamepad.polling.start"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isRunning ? Color(red: 0.78, green: 0.34, blue: 0.47) : Color(red: 0.55, green: 0.51, blue: 0.93))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadPollingAnomalySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let anomalyDetails: [GamepadPollingAnomalyDetail]
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Group {
                if anomalyDetails.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(Color(red: 0.39, green: 0.78, blue: 0.69))
                        Text(GamepadLocalized("gamepad.polling.no_anomalies"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.94) : Color(red: 0.29, green: 0.22, blue: 0.42))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemGroupedBackground))
                } else {
                    List(anomalyDetails) { detail in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(GamepadLocalizedFormat("gamepad.polling.sample", detail.sampleIndex))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.94) : Color(red: 0.29, green: 0.22, blue: 0.42))

                                Text(detail.kind.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(detail.kind == .tooSlow ? Color(red: 0.76, green: 0.38, blue: 0.28) : Color(red: 0.30, green: 0.55, blue: 0.86))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(detail.kind == .tooSlow
                                                  ? (colorScheme == .dark ? Color(red: 0.48, green: 0.25, blue: 0.20).opacity(0.78) : Color(red: 0.99, green: 0.91, blue: 0.86))
                                                  : (colorScheme == .dark ? Color(red: 0.18, green: 0.31, blue: 0.48).opacity(0.82) : Color(red: 0.88, green: 0.94, blue: 0.99)))
                                    )
                            }

                            Text(GamepadLocalizedFormat("gamepad.polling.interval_average", detail.intervalMs, detail.averageMs))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.68) : Color(red: 0.43, green: 0.35, blue: 0.60))
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(colorScheme == .dark ? Color(red: 0.12, green: 0.11, blue: 0.18) : Color(UIColor.systemBackground))
                    }
                    .listStyle(GroupedListStyle())
                }
            }
            .background(colorScheme == .dark ? Color(red: 0.09, green: 0.09, blue: 0.13) : Color(UIColor.systemGroupedBackground))
            .navigationBarTitle(Text(GamepadLocalized("gamepad.polling.details_title")), displayMode: .inline)
            .navigationBarItems(trailing: Button(GamepadLocalized("common.done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadTriggerView: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.72) : Color(red: 0.34, green: 0.27, blue: 0.48))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.62))
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color(red: 0.55, green: 0.51, blue: 0.93))
                        .frame(width: max(8, proxy.size.width * CGFloat(min(max(value, 0), 1))))
                }
            }
            .frame(height: 12)

            Text("\(Int((min(max(value, 0), 1) * 255).rounded()))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.64) : Color(red: 0.45, green: 0.38, blue: 0.60))
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 13.0, *)
private struct GamepadButtonCapsule: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let isPressed: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isPressed ? .white : (colorScheme == .dark ? Color.white.opacity(0.88) : Color(red: 0.34, green: 0.27, blue: 0.48)))
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isPressed ? Color(red: 0.55, green: 0.51, blue: 0.93) : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.76)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.72), lineWidth: 1)
            )
    }
}

@available(iOS 13.0, *)
private struct GamepadRoundButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let isPressed: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(isPressed ? .white : (colorScheme == .dark ? Color.white.opacity(0.88) : Color(red: 0.30, green: 0.25, blue: 0.43)))
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(isPressed ? Color(red: 0.55, green: 0.51, blue: 0.93) : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.78)))
            )
            .overlay(
                Circle()
                    .stroke(isPressed ? Color.white.opacity(0.92) : (colorScheme == .dark ? Color.white.opacity(0.12) : Color(red: 0.63, green: 0.60, blue: 0.72).opacity(0.85)), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(isPressed ? (colorScheme == .dark ? 0.20 : 0.10) : (colorScheme == .dark ? 0.12 : 0.04)), radius: isPressed ? 10 : 6, x: 0, y: 4)
    }
}

@available(iOS 13.0, *)
private struct GamepadStickView: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let x: Double
    let y: Double
    let isPressed: Bool
    let showTrail: Bool
    let trailPoints: [GamepadTrailPoint]

    private struct TrailBucket: Identifiable {
        let id: Int
        let path: Path
        let opacity: Double
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let radius = side / 2
                let knobDiameter = side * 0.12
                let knobRadius = knobDiameter / 2
                let ringInset = 1.0
                let travel = radius - knobRadius - ringInset
                let currentTime = CACurrentMediaTime()
                let trailBuckets = makeTrailBuckets(radius: radius, travel: travel, currentTime: currentTime)

                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.76))

                    Circle()
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color(red: 0.63, green: 0.60, blue: 0.72).opacity(0.75), lineWidth: 0.8)

                    if showTrail && !trailBuckets.isEmpty {
                        ForEach(trailBuckets) { bucket in
                            bucket.path.stroke(
                                Color(red: 0.55, green: 0.51, blue: 0.93).opacity(0.08 + bucket.opacity * 0.42),
                                style: StrokeStyle(
                                    lineWidth: max(1.4, side * 0.02),
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                        }
                    }

                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08))
                        .frame(width: side * 0.07, height: side * 0.07)

                    Circle()
                        .fill(isPressed ? Color(red: 0.55, green: 0.51, blue: 0.93) : (colorScheme == .dark ? Color.white.opacity(0.72) : Color(red: 0.38, green: 0.36, blue: 0.46)))
                        .frame(width: knobDiameter, height: knobDiameter)
                        .offset(
                            x: CGFloat(min(max(x, -1), 1)) * travel,
                            y: CGFloat(min(max(y, -1), 1)) * travel
                        )
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.12), radius: 10, x: 0, y: 4)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 100)

            Text(String(format: "X %.2f  Y %.2f", x, y))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.64) : Color(red: 0.45, green: 0.38, blue: 0.60))
        }
        .frame(maxWidth: .infinity)
    }

    private func trailOpacity(for timestamp: CFTimeInterval, currentTime: CFTimeInterval) -> Double {
        let age = max(0, currentTime - timestamp)
        if age <= GamepadTrailStyle.fadeDelay {
            return 1.0
        }

        let fadeProgress = min(max((age - GamepadTrailStyle.fadeDelay) / GamepadTrailStyle.fadeDuration, 0), 1)
        return 1.0 - fadeProgress
    }

    private func makeTrailBuckets(radius: CGFloat, travel: CGFloat, currentTime: CFTimeInterval) -> [TrailBucket] {
        guard trailPoints.count > 1 else {
            return []
        }

        var bucketPaths = Array(repeating: Path(), count: GamepadTrailStyle.opacityBucketCount)

        for index in trailPoints.indices.dropFirst() {
            let previous = trailPoints[index - 1]
            let current = trailPoints[index]
            let previousOpacity = trailOpacity(for: previous.timestamp, currentTime: currentTime)
            let currentOpacity = trailOpacity(for: current.timestamp, currentTime: currentTime)
            let segmentOpacity = min(previousOpacity, currentOpacity)

            guard segmentOpacity > 0 else {
                continue
            }

            let bucketIndex = min(
                GamepadTrailStyle.opacityBucketCount - 1,
                max(0, Int(segmentOpacity * Double(GamepadTrailStyle.opacityBucketCount - 1)))
            )

            bucketPaths[bucketIndex].move(to: CGPoint(
                x: radius + previous.point.x * travel,
                y: radius + previous.point.y * travel
            ))
            bucketPaths[bucketIndex].addLine(to: CGPoint(
                x: radius + current.point.x * travel,
                y: radius + current.point.y * travel
            ))
        }

        return bucketPaths.enumerated().compactMap { index, path in
            guard !path.isEmpty else {
                return nil
            }

            let opacity = Double(index + 1) / Double(GamepadTrailStyle.opacityBucketCount)
            return TrailBucket(id: index, path: path, opacity: opacity)
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadVisualizationCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let showStickTrails: Bool
    let onShowStickTrailsChanged: (Bool) -> Void

    var body: some View {
        GamepadCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(GamepadLocalized("gamepad.card.visualization"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.94) : Color(red: 0.29, green: 0.22, blue: 0.42))

                Toggle(isOn: Binding(get: {
                    showStickTrails
                }, set: { newValue in
                    onShowStickTrailsChanged(newValue)
                })) {
                    Text(GamepadLocalized("gamepad.visualization.show_trails"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.88) : Color(red: 0.29, green: 0.22, blue: 0.42))
                }
            }
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadDPadView: View {
    let up: Bool
    let down: Bool
    let left: Bool
    let right: Bool

    var body: some View {
        ZStack {
            Color.clear
            VStack(spacing: 4) {
                GamepadRoundButton(title: "▲", isPressed: up)
                HStack(spacing: 4) {
                    GamepadRoundButton(title: "◀", isPressed: left)
                    Color.clear
                        .frame(width: 32, height: 32)
                    GamepadRoundButton(title: "▶", isPressed: right)
                }
                GamepadRoundButton(title: "▼", isPressed: down)
            }
        }
        .frame(width: 102, height: 102)
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 13.0, *)
private struct GamepadFaceButtonsView: View {
    let a: Bool
    let b: Bool
    let x: Bool
    let y: Bool

    var body: some View {
        ZStack {
            Color.clear
            VStack(spacing: 4) {
                GamepadRoundButton(title: "Y", isPressed: y)
                HStack(spacing: 4) {
                    GamepadRoundButton(title: "X", isPressed: x)
                    Color.clear
                        .frame(width: 32, height: 32)
                    GamepadRoundButton(title: "B", isPressed: b)
                }
                GamepadRoundButton(title: "A", isPressed: a)
            }
        }
        .frame(width: 102, height: 102)
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 13.0, *)
private struct GamepadCenterButtonsView: View {
    let menu: Bool
    let options: Bool
    let leftShoulder: Bool
    let rightShoulder: Bool
    
    let leftPressed: Bool
    let rightPressed: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                GamepadButtonCapsule(title: "L1", isPressed: leftShoulder)
                GamepadButtonCapsule(title: "R1", isPressed: rightShoulder)
            }

            HStack(spacing: 8) {
                GamepadButtonCapsule(title: "select", isPressed: options)
                GamepadButtonCapsule(title: "start", isPressed: menu)
            }
            
            HStack(spacing: 8) {
                GamepadButtonCapsule(title: "L3", isPressed: leftPressed)
                GamepadButtonCapsule(title: "R3", isPressed: rightPressed)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 13.0, *)
private struct GamepadControllerLayoutCard: View {
    @ObservedObject var model: GamepadTestViewModel
    let compact: Bool

    var body: some View {
        GamepadCard {
            VStack(spacing: compact ? 10 : 16) {
                HStack(spacing: compact ? 8 : 12) {
                    GamepadTriggerView(title: "L2", value: model.leftTrigger)
                    GamepadTriggerView(title: "R2", value: model.rightTrigger)
                }

                HStack(alignment: .top, spacing: compact ? 8 : 14) {
                    GamepadDPadView(
                        up: model.dpadUp,
                        down: model.dpadDown,
                        left: model.dpadLeft,
                        right: model.dpadRight
                    )

                    VStack(spacing: compact ? 8 : 14) {
                        GamepadCenterButtonsView(
                            menu: model.menuButton,
                            options: model.optionsButton,
                            leftShoulder: model.leftShoulder,
                            rightShoulder: model.rightShoulder,
                            leftPressed: model.leftThumbstickButton,
                            rightPressed: model.rightThumbstickButton
                        )
                    }
                    .frame(maxWidth: .infinity)

                    GamepadFaceButtonsView(
                        a: model.buttonA,
                        b: model.buttonB,
                        x: model.buttonX,
                        y: model.buttonY
                    )
                }

                HStack(alignment: .top, spacing: compact ? 8 : 14) {
                    GamepadStickView(
                        title: GamepadLocalized("gamepad.stick.left"),
                        x: model.leftStickX,
                        y: model.leftStickY,
                        isPressed: model.leftThumbstickButton,
                        showTrail: model.showStickTrails,
                        trailPoints: model.leftStickTrailPoints
                    )

                    GamepadStickView(
                        title: GamepadLocalized("gamepad.stick.right"),
                        x: model.rightStickX,
                        y: model.rightStickY,
                        isPressed: model.rightThumbstickButton,
                        showTrail: model.showStickTrails,
                        trailPoints: model.rightStickTrailPoints
                    )
                }
            }
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadTestRootView: View {
    @ObservedObject var model: GamepadTestViewModel

    var body: some View {
        ZStack {
            GamepadTestBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    GamepadStatusCard(title: model.controllerName, subtitle: model.connectionDescription)

                    GamepadCurrentDeviceCard(
                        deviceModel: model.deviceModelText,
                        systemVersion: model.systemVersionText
                    )

                    GamepadDeviceInfoCard(
                        vendor: model.controllerName,
                        profile: model.profileName,
                        playerIndex: model.playerIndexText,
                        battery: model.batteryText,
                        haptics: model.hapticsText,
                        connectionType: model.connectionTypeText,
                        gyroSupport: model.gyroSupportText,
                        inferredControllerType: model.inferredControllerTypeText
                    )

                    GamepadRumbleTestCard(
                        statusText: model.rumbleStatusText,
                        isRumbling: model.isRumbling,
                        triggerRumbleEnabled: model.triggerRumbleEnabled,
                        onTrigger: {
                            model.toggleManualRumble()
                        },
                        onTriggerModeChanged: { enabled in
                            model.setTriggerRumbleEnabled(enabled)
                        }
                    )

                    GamepadGyroTestCard(
                        isEnabled: model.gyroEnabled,
                        selectedSourceIndex: model.gyroSourceIndex,
                        controllerGyroSupported: model.controllerGyroSupported,
                        statusText: model.gyroStatusText,
                        hintText: model.gyroHintText,
                        x: model.gyroX,
                        y: model.gyroY,
                        z: model.gyroZ,
                        onEnabledChanged: { enabled in
                            model.setGyroEnabled(enabled)
                        },
                        onSourceChanged: { newValue in
                            model.setGyroSourceIndex(newValue)
                        }
                    )

                    GamepadPollingTestCard(
                        statusText: model.pollingStatusText,
                        progressText: model.pollingProgressText,
                        hzText: model.pollingHzText,
                        minText: model.pollingMinText,
                        maxText: model.pollingMaxText,
                        avgText: model.pollingAvgText,
                        anomalyCountText: model.pollingAnomalyCountText,
                        hasAnomalyDetails: !model.pollingAnomalyDetails.isEmpty,
                        isRunning: model.isPollingTestRunning,
                        onShowAnomalies: {
                            model.presentPollingAnomalySheet()
                        },
                        onTrigger: {
                            model.togglePollingTest()
                        }
                    )

                    GamepadVisualizationCard(
                        showStickTrails: model.showStickTrails,
                        onShowStickTrailsChanged: { enabled in
                            model.setShowStickTrails(enabled)
                        }
                    )

                    GamepadControllerLayoutCard(model: model, compact: false)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: Binding(get: {
            model.isShowingPollingAnomalySheet
        }, set: { newValue in
            model.isShowingPollingAnomalySheet = newValue
        })) {
            GamepadPollingAnomalySheet(anomalyDetails: model.pollingAnomalyDetails)
        }
    }
}

@objcMembers
@available(iOS 13.0, *)
final class GamepadTestHostingViewController: UIViewController {
    private let model = GamepadTestViewModel()
    private var hostingController: UIHostingController<GamepadTestRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        title = GamepadLocalized("gamepad.title")
        installHostingControllerIfNeeded()
        applyNavigationBarAppearance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyNavigationBarAppearance()
    }

    private func installHostingControllerIfNeeded() {
        let rootView = GamepadTestRootView(model: model)
        if let hostingController {
            hostingController.rootView = rootView
            return
        }

        let hostingController = UIHostingController(rootView: rootView)
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }

    private func applyNavigationBarAppearance() {
        let navigationBar = navigationController?.navigationBar
        guard let navigationBar else { return }

        let darkMode = traitCollection.userInterfaceStyle == .dark
        let accentColor = darkMode ? UIColor(red: 0.90, green: 0.85, blue: 0.99, alpha: 1.0) : UIColor(red: 0.31, green: 0.23, blue: 0.46, alpha: 1.0)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: accentColor,
            .font: UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        ]

        navigationBar.tintColor = accentColor
        navigationBar.titleTextAttributes = titleAttributes

        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = titleAttributes

        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear

        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationBar.compactScrollEdgeAppearance = appearance
        }
        navigationBar.isTranslucent = true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if #available(iOS 13.0, *),
           let previousTraitCollection,
           traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyNavigationBarAppearance()
        }
    }
}
#endif
