import UIKit
#if canImport(SwiftUI)
import SwiftUI
import GameController
import CoreHaptics
import CoreMotion
import QuartzCore
import AudioToolbox

@available(iOS 13.0, *)
private struct GamepadTrailPoint: Identifiable {
    let id = UUID()
    let point: CGPoint
    let timestamp: CFTimeInterval
}

@available(iOS 13.0, *)
private final class GamepadTestViewModel: NSObject, ObservableObject {
    @Published var controllerName: String = "未连接手柄"
    @Published var connectionDescription: String = "连接手柄后会实时显示按键、摇杆和扳机状态"
    @Published var profileName: String = "Extended Gamepad"
    @Published var playerIndexText: String = "未分配"
    @Published var batteryText: String = "未知"
    @Published var hapticsText: String = "未检测"
    @Published var connectionTypeText: String = "未知（系统未公开）"
    @Published var gyroSupportText: String = "未检测"
    @Published var inferredControllerTypeText: String = "未识别"
    @Published var rumbleStatusText: String = "点击开始震动"
    @Published var isRumbling = false
    @Published var triggerRumbleEnabled = false
    @Published var pollingStatusText: String = "点击开始，转动左摇杆"
    @Published var isPollingTestRunning = false
    @Published var pollingProgressText: String = "0 / 1000"
    @Published var pollingHzText: String = "--"
    @Published var pollingMinText: String = "--"
    @Published var pollingMaxText: String = "--"
    @Published var pollingAvgText: String = "--"
    @Published var pollingAnomalyCountText: String = "--"
    @Published var showStickTrails = false
    @Published var gyroEnabled = false
    @Published var gyroSourceIndex = 0
    @Published var gyroStatusText: String = "机身体感"
    @Published var gyroHintText: String = "左右倾斜设备，观察小圆点摆动"
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
    private var fallbackVibrationTimer: Timer?
    private var stickTrailCleanupTimer: Timer?
    private var leftStickPollingTimestamps: [CFTimeInterval] = []
    private var lastPolledLeftStickX: Double = 0
    private var lastPolledLeftStickY: Double = 0
    private let pollingTargetCount = 1000
    private let deviceMotionManager = CMMotionManager()
    private let stickTrailLifetime: CFTimeInterval = 3.0

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

        controllerName = controller.vendorName ?? "已连接手柄"
        connectionDescription = "请按下手柄按键，界面会实时高亮当前输入"
        profileName = controller.extendedGamepad != nil ? "Extended Gamepad" : "基础手柄"
        playerIndexText = playerIndexDescription(for: controller.playerIndex)
        batteryText = batteryDescription(for: controller)
        hapticsText = hapticsDescription(for: controller)
        connectionTypeText = inferredConnectionType(for: controller)
        controllerGyroSupported = controllerSupportsGyro(controller)
        gyroSupportText = controllerGyroSupported ? "支持陀螺仪" : "不支持"
        inferredControllerTypeText = inferredControllerType(for: controller)
        stopActiveRumble()
        triggerRumbleEnabled = false
        rumbleStatusText = "点击开始震动"
        resetPollingTest(resetResult: true)

        if let gamepad = controller.extendedGamepad {
            gamepad.valueChangedHandler = { [weak self] gamepad, _ in
                self?.update(with: gamepad)
            }
            update(with: gamepad)
        }
        else {
            connectionDescription = "当前手柄不是扩展手柄类型，部分按键可能无法检测"
        }

        configureGyroMonitoring()
    }

    private func resetState() {
        controllerName = "未连接手柄"
        connectionDescription = "连接手柄后会实时显示按键、摇杆和扳机状态"
        profileName = "Extended Gamepad"
        playerIndexText = "未分配"
        batteryText = "未知"
        hapticsText = "未检测"
        connectionTypeText = "未知（系统未公开）"
        gyroSupportText = "未检测"
        inferredControllerTypeText = "未识别"
        rumbleStatusText = "点击开始震动"
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
        gyroStatusText = gyroSourceIndex == 1 ? "手柄体感" : "机身体感"
        gyroHintText = "左右倾斜设备，观察小圆点摆动"
        gyroX = 0
        gyroY = 0
        gyroZ = 0
        gyroEnabled = false
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
            gyroStatusText = gyroSourceIndex == 1 ? "手柄体感" : "机身体感"
            gyroHintText = "开启体感测试后显示实时数据"
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
        let maxTrailCount = 48
        let trailPoint = GamepadTrailPoint(point: normalizedPoint, timestamp: CACurrentMediaTime())

        if toLeftStick {
            leftStickTrailPoints.append(trailPoint)
            if leftStickTrailPoints.count > maxTrailCount {
                leftStickTrailPoints.removeFirst(leftStickTrailPoints.count - maxTrailCount)
            }
        }
        else {
            rightStickTrailPoints.append(trailPoint)
            if rightStickTrailPoints.count > maxTrailCount {
                rightStickTrailPoints.removeFirst(rightStickTrailPoints.count - maxTrailCount)
            }
        }
    }

    private func clearStickTrails() {
        leftStickTrailPoints = []
        rightStickTrailPoints = []
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
        let threshold = CACurrentMediaTime() - stickTrailLifetime
        leftStickTrailPoints.removeAll { $0.timestamp < threshold }
        rightStickTrailPoints.removeAll { $0.timestamp < threshold }
    }

    private func startDeviceGyroMonitoring() {
        gyroStatusText = "机身体感"

        guard deviceMotionManager.isGyroAvailable else {
            gyroHintText = "当前设备不支持机身陀螺仪"
            gyroX = 0
            gyroY = 0
            gyroZ = 0
            return
        }

        gyroHintText = "左右倾斜设备，观察小圆点摆动"
        deviceMotionManager.gyroUpdateInterval = 1.0 / 60.0
        deviceMotionManager.startGyroUpdates(to: .main) { [weak self] data, _ in
            guard let self, let rotationRate = data?.rotationRate else { return }
            self.gyroX = rotationRate.x
            self.gyroY = rotationRate.y
            self.gyroZ = rotationRate.z
        }
    }

    private func startControllerGyroMonitoring() {
        gyroStatusText = "手柄体感"

        guard let motion = currentController?.motion, controllerSupportsGyro(currentController) else {
            gyroHintText = "当前手柄不支持陀螺仪"
            gyroX = 0
            gyroY = 0
            gyroZ = 0
            return
        }

        gyroHintText = "转动手柄，观察小圆点摆动"

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
        pollingStatusText = "点击开始，转动左摇杆"
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
            return "未分配"
        case .index1:
            return "Player 1"
        case .index2:
            return "Player 2"
        case .index3:
            return "Player 3"
        case .index4:
            return "Player 4"
        @unknown default:
            return "未知"
        }
    }

    private func batteryDescription(for controller: GCController) -> String {
        if #available(iOS 14.0, *), let battery = controller.battery {
            let level = Int((battery.batteryLevel * 100).rounded())
            switch battery.batteryState {
            case .charging:
                return "\(level)% 充电中"
            case .discharging:
                return "\(level)%"
            case .full:
                return "100% 已充满"
            case .unknown:
                return "未知"
            @unknown default:
                return "未知"
            }
        }

        return "不支持"
    }

    private func hapticsDescription(for controller: GCController) -> String {
        if #available(iOS 14.0, *), let haptics = controller.haptics {
            let localities = haptics.supportedLocalities
            if localities.contains(GCHapticsLocality.rightHandle) || localities.contains(GCHapticsLocality.leftHandle) {
                return "支持手柄震动"
            }
            return "支持有限"
        }

        return "不支持"
    }

    private func inferredControllerType(for controller: GCController) -> String {
        let vendor = (controller.vendorName ?? "").lowercased()

        if vendor.contains("xbox") {
            return "Xbox 类手柄"
        }
        if vendor.contains("dualsense") || vendor.contains("dualshock") || vendor.contains("playstation") || vendor.contains("ps5") || vendor.contains("ps4") {
            return "PlayStation 类手柄"
        }
        if vendor.contains("switch") || vendor.contains("joy-con") || vendor.contains("pro controller") {
            return "Switch 类手柄"
        }
        if vendor.contains("8bitdo") {
            return "8BitDo 手柄"
        }
        if vendor.contains("gamesir") {
            return "GameSir 手柄"
        }
        if vendor.contains("razer") {
            return "Razer 手柄"
        }
        if controller.extendedGamepad != nil {
            return "通用扩展手柄"
        }
        return "通用手柄"
    }

    private func inferredConnectionType(for controller: GCController) -> String {
        if controller.isAttachedToDevice {
            return "贴附/直连设备"
        }
        return "外接手柄（蓝牙/USB 未公开）"
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
        fallbackVibrationTimer?.invalidate()
        fallbackVibrationTimer = nil
        isRumbling = false
    }

    private func startContinuousDeviceVibration() {
        fallbackVibrationTimer?.invalidate()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        fallbackVibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        isRumbling = true
    }

    @available(iOS 14.0, *)
    private func startContinuousRumble(for localities: [GCHapticsLocality]) -> Bool {
        if #available(iOS 14.0, *), let controller = currentController, let haptics = controller.haptics {
            let supportedLocalities = haptics.supportedLocalities
            var startedAny = false

            for locality in localities where supportedLocalities.contains(locality) {
                do {
                    guard let engine = haptics.createEngine(withLocality: locality) else {
                        continue
                    }
                    try engine.start()

                    let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75)
                    let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
                    let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 60)
                    let pattern = try CHHapticPattern(events: [event], parameters: [])
                    let player = try engine.makePlayer(with: pattern)
                    try player.start(atTime: 0)

                    if locality == .leftHandle {
                        leftHapticEngine = engine
                        leftHapticPlayer = player
                    }
                    else if locality == .rightHandle {
                        rightHapticEngine = engine
                        rightHapticPlayer = player
                    }
                    startedAny = true
                }
                catch {
                    continue
                }
            }

            if startedAny {
                isRumbling = true
                return true
            }
        }

        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
        return false
    }

    @available(iOS 14.0, *)
    private func syncTriggerDrivenRumble() {
        guard triggerRumbleEnabled else { return }
        let shouldRumbleLeft = leftTrigger > 0.08
        let shouldRumbleRight = rightTrigger > 0.08

        stopActiveRumble()

        var localities: [GCHapticsLocality] = []
        if shouldRumbleLeft {
            localities.append(.leftHandle)
        }
        if shouldRumbleRight {
            localities.append(.rightHandle)
        }

        if localities.isEmpty {
            rumbleStatusText = "扳机联动震动已开启"
            return
        }

        if startContinuousRumble(for: localities) {
            rumbleStatusText = "扳机按下，震动中"
        }
        else {
            stopActiveRumble()
            rumbleStatusText = "当前手柄不支持持续震动"
            triggerRumbleEnabled = false
        }
    }

    func toggleManualRumble() {
        triggerRumbleEnabled = false
        if isRumbling {
            stopActiveRumble()
            rumbleStatusText = "震动已停止"
            return
        }

        if #available(iOS 14.0, *), startContinuousRumble(for: [.leftHandle, .rightHandle]) {
            rumbleStatusText = "震动进行中"
        }
        else {
            startContinuousDeviceVibration()
            rumbleStatusText = "当前手柄不支持持续震动，已切换为设备震动"
        }
    }

    func setTriggerRumbleEnabled(_ enabled: Bool) {
        triggerRumbleEnabled = enabled
        if !enabled {
            if isRumbling {
                stopActiveRumble()
            }
            rumbleStatusText = "点击开始震动"
            return
        }

        if #available(iOS 14.0, *) {
            syncTriggerDrivenRumble()
            if !isRumbling {
                rumbleStatusText = "扣动扳机后震动"
            }
        }
        else {
            triggerRumbleEnabled = false
            rumbleStatusText = "当前系统不支持扳机联动震动"
        }
    }

    func togglePollingTest() {
        if isPollingTestRunning {
            resetPollingTest(resetResult: false)
            pollingStatusText = "测试已停止"
            return
        }

        leftStickPollingTimestamps.removeAll()
        isPollingTestRunning = true
        pollingStatusText = "测试中，请持续转动左摇杆"
        pollingProgressText = "0 / \(pollingTargetCount)"
        pollingHzText = "--"
        pollingMinText = "--"
        pollingMaxText = "--"
        pollingAvgText = "--"
        pollingAnomalyCountText = "--"
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
        leftStickPollingTimestamps.append(CACurrentMediaTime())
        pollingProgressText = "\(leftStickPollingTimestamps.count) / \(pollingTargetCount)"

        guard leftStickPollingTimestamps.count >= pollingTargetCount else { return }
        finalizePollingTest()
    }

    private func finalizePollingTest() {
        isPollingTestRunning = false

        let intervals = zip(leftStickPollingTimestamps.dropFirst(), leftStickPollingTimestamps.dropLast()).map { current, previous in
            current - previous
        }.filter { $0 > 0 }

        guard !intervals.isEmpty else {
            pollingStatusText = "数据不足，请重新测试"
            pollingHzText = "--"
            pollingMinText = "--"
            pollingMaxText = "--"
            pollingAvgText = "--"
            pollingAnomalyCountText = "--"
            return
        }

        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        let minimumInterval = intervals.min() ?? averageInterval
        let maximumInterval = intervals.max() ?? averageInterval
        let anomalyCount = intervals.filter { $0 > averageInterval * 2.0 || $0 < averageInterval * 0.5 }.count
        let hz = averageInterval > 0 ? 1.0 / averageInterval : 0

        pollingStatusText = "测试完成"
        pollingHzText = String(format: "%.1f Hz", hz)
        pollingMinText = String(format: "%.2f ms", minimumInterval * 1000)
        pollingMaxText = String(format: "%.2f ms", maximumInterval * 1000)
        pollingAvgText = String(format: "%.2f ms", averageInterval * 1000)
        pollingAnomalyCountText = "\(anomalyCount)"
    }

    private func update(with gamepad: GCExtendedGamepad) {
        DispatchQueue.main.async {
            guard let controller = gamepad.controller else { return }

            self.playerIndexText = self.playerIndexDescription(for: controller.playerIndex)
            self.batteryText = self.batteryDescription(for: controller)
            self.hapticsText = self.hapticsDescription(for: controller)
            self.connectionTypeText = self.inferredConnectionType(for: controller)
            self.gyroSupportText = self.controllerSupportsGyro(controller) ? "支持陀螺仪" : "不支持"
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
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.95, green: 0.89, blue: 0.99),
                Color(red: 0.86, green: 0.78, blue: 0.98),
                Color(red: 0.70, green: 0.63, blue: 0.93)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .edgesIgnoringSafeArea(.all)
    }
}

@available(iOS 13.0, *)
private struct GamepadCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.80))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.68), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 8)
    }
}

@available(iOS 13.0, *)
private struct GamepadStatusCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        GamepadCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.27, green: 0.20, blue: 0.40))

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.42, green: 0.35, blue: 0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.36, green: 0.29, blue: 0.50))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.26, green: 0.21, blue: 0.39))
                .multilineTextAlignment(.trailing)
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadDeviceInfoCard: View {
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
                Text("设备信息")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.29, green: 0.22, blue: 0.42))

                GamepadInfoRow(title: "设备名称", value: vendor)
                GamepadInfoRow(title: "手柄配置", value: profile)
                GamepadInfoRow(title: "玩家编号", value: playerIndex)
                GamepadInfoRow(title: "连接方式", value: connectionType)
                GamepadInfoRow(title: "电量", value: battery)
                GamepadInfoRow(title: "震动支持", value: haptics)
                GamepadInfoRow(title: "陀螺仪支持", value: gyroSupport)
                GamepadInfoRow(title: "手柄类型", value: inferredControllerType)
            }
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadRumbleTestCard: View {
    let statusText: String
    let isRumbling: Bool
    let triggerRumbleEnabled: Bool
    let onTrigger: () -> Void
    let onTriggerModeChanged: (Bool) -> Void

    var body: some View {
        GamepadCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("震动测试")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.29, green: 0.22, blue: 0.42))

                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.43, green: 0.35, blue: 0.60))

                Button(action: onTrigger) {
                    HStack(spacing: 10) {
                        Image(systemName: "wave.3.right.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(isRumbling ? "停止震动" : "开始震动")
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
                    Text("扣动扳机后震动")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.29, green: 0.22, blue: 0.42))
                }
            }
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadGyroMeterRow: View {
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
                    .foregroundColor(Color(red: 0.36, green: 0.29, blue: 0.50))
                Spacer(minLength: 8)
                Text(String(format: "%.2f rad/s", value))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 0.45, green: 0.38, blue: 0.60))
            }

            GeometryReader { proxy in
                let trackWidth = proxy.size.width
                let dotSize: CGFloat = 16
                let centerX = trackWidth / 2
                let maxOffset = max(0, (trackWidth - dotSize) / 2)

                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.72))

                    Capsule()
                        .fill(tint.opacity(0.18))
                        .padding(.vertical, 2)

                    Rectangle()
                        .fill(Color.white.opacity(0.95))
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
                Text("体感测试")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.29, green: 0.22, blue: 0.42))

                Toggle(isOn: Binding(get: {
                    isEnabled
                }, set: { newValue in
                    onEnabledChanged(newValue)
                })) {
                    Text("启用体感测试")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.29, green: 0.22, blue: 0.42))
                }

                Picker("", selection: Binding(get: {
                    selectedSourceIndex
                }, set: { newValue in
                    onSourceChanged(newValue)
                })) {
                    Text("机身体感").tag(0)
                    Text("手柄体感").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())

                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.29, green: 0.22, blue: 0.42))

                Text(controllerGyroSupported || selectedSourceIndex == 0 ? hintText : "当前手柄不支持陀螺仪")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.43, green: 0.35, blue: 0.60))

                if isEnabled {
                    GamepadGyroMeterRow(
                        title: "X轴",
                        value: x,
                        tint: Color(red: 0.46, green: 0.52, blue: 0.95)
                    )
                    GamepadGyroMeterRow(
                        title: "Y轴",
                        value: y,
                        tint: Color(red: 0.39, green: 0.78, blue: 0.69)
                    )
                    GamepadGyroMeterRow(
                        title: "Z轴",
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
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 0.36, green: 0.29, blue: 0.50))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0.26, green: 0.21, blue: 0.39))
        }
    }
}

@available(iOS 13.0, *)
private struct GamepadPollingTestCard: View {
    let statusText: String
    let progressText: String
    let hzText: String
    let minText: String
    let maxText: String
    let avgText: String
    let anomalyCountText: String
    let isRunning: Bool
    let onTrigger: () -> Void

    var body: some View {
        GamepadCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("摇杆轮询率测试")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.29, green: 0.22, blue: 0.42))

                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.43, green: 0.35, blue: 0.60))

                GamepadPollingStatRow(title: "采样进度", value: progressText)
                GamepadPollingStatRow(title: "轮询率", value: hzText)
                GamepadPollingStatRow(title: "最小值", value: minText)
                GamepadPollingStatRow(title: "最大值", value: maxText)
                GamepadPollingStatRow(title: "平均值", value: avgText)
                GamepadPollingStatRow(title: "异常值数量", value: anomalyCountText)

                Button(action: onTrigger) {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.path.ecg.rectangle")
                            .font(.system(size: 18, weight: .semibold))
                        Text(isRunning ? "停止测试" : "开始测试")
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
private struct GamepadTriggerView: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 0.34, green: 0.27, blue: 0.48))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.62))
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color(red: 0.55, green: 0.51, blue: 0.93))
                        .frame(width: max(8, proxy.size.width * CGFloat(min(max(value, 0), 1))))
                }
            }
            .frame(height: 12)

            Text("\(Int((min(max(value, 0), 1) * 255).rounded()))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.45, green: 0.38, blue: 0.60))
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 13.0, *)
private struct GamepadButtonCapsule: View {
    let title: String
    let isPressed: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isPressed ? .white : Color(red: 0.34, green: 0.27, blue: 0.48))
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isPressed ? Color(red: 0.55, green: 0.51, blue: 0.93) : Color.white.opacity(0.76))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
    }
}

@available(iOS 13.0, *)
private struct GamepadRoundButton: View {
    let title: String
    let isPressed: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(isPressed ? .white : Color(red: 0.30, green: 0.25, blue: 0.43))
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(isPressed ? Color(red: 0.55, green: 0.51, blue: 0.93) : Color.white.opacity(0.78))
            )
            .overlay(
                Circle()
                    .stroke(isPressed ? Color.white.opacity(0.92) : Color(red: 0.63, green: 0.60, blue: 0.72).opacity(0.85), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(isPressed ? 0.10 : 0.04), radius: isPressed ? 10 : 6, x: 0, y: 4)
    }
}

@available(iOS 13.0, *)
private struct GamepadStickView: View {
    let title: String
    let x: Double
    let y: Double
    let isPressed: Bool
    let showTrail: Bool
    let trailPoints: [GamepadTrailPoint]

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

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.76))

                    Circle()
                        .stroke(Color(red: 0.63, green: 0.60, blue: 0.72).opacity(0.75), lineWidth: 0.8)

                    if showTrail && trailPoints.count > 1 {
                        ForEach(Array(trailPoints.indices.dropFirst()), id: \.self) { index in
                            let previous = trailPoints[index - 1]
                            let current = trailPoints[index]
                            let age = max(0, min(1, 1 - ((currentTime - current.timestamp) / 3.0)))

                            Path { path in
                                path.move(to: CGPoint(
                                    x: radius + previous.point.x * travel,
                                    y: radius + previous.point.y * travel
                                ))
                                path.addLine(to: CGPoint(
                                    x: radius + current.point.x * travel,
                                    y: radius + current.point.y * travel
                                ))
                            }
                            .stroke(
                                Color(red: 0.55, green: 0.51, blue: 0.93).opacity(0.10 + age * 0.45),
                                style: StrokeStyle(
                                    lineWidth: max(1.4, side * 0.02),
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                        }
                    }

                    Circle()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: side * 0.07, height: side * 0.07)

                    Circle()
                        .fill(isPressed ? Color(red: 0.55, green: 0.51, blue: 0.93) : Color(red: 0.38, green: 0.36, blue: 0.46))
                        .frame(width: knobDiameter, height: knobDiameter)
                        .offset(
                            x: CGFloat(min(max(x, -1), 1)) * travel,
                            y: CGFloat(min(max(y, -1), 1)) * travel
                        )
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 100)

            Text(String(format: "X %.2f  Y %.2f", x, y))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 0.45, green: 0.38, blue: 0.60))
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 13.0, *)
private struct GamepadVisualizationCard: View {
    let showStickTrails: Bool
    let onShowStickTrailsChanged: (Bool) -> Void

    var body: some View {
        GamepadCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("手柄 UI可视化")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.29, green: 0.22, blue: 0.42))

                Toggle(isOn: Binding(get: {
                    showStickTrails
                }, set: { newValue in
                    onShowStickTrailsChanged(newValue)
                })) {
                    Text("显示摇杆轨迹")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.29, green: 0.22, blue: 0.42))
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
                        title: "左摇杆",
                        x: model.leftStickX,
                        y: model.leftStickY,
                        isPressed: model.leftThumbstickButton,
                        showTrail: model.showStickTrails,
                        trailPoints: model.leftStickTrailPoints
                    )

                    GamepadStickView(
                        title: "右摇杆",
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

//                    GamepadVisualizationCard(
//                        showStickTrails: model.showStickTrails,
//                        onShowStickTrailsChanged: { enabled in
//                            model.setShowStickTrails(enabled)
//                        }
//                    )

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
                        isRunning: model.isPollingTestRunning,
                        onTrigger: {
                            model.togglePollingTest()
                        }
                    )

                    GamepadControllerLayoutCard(model: model, compact: false)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
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
        title = "手柄测试"
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

        let accentColor = UIColor(red: 0.31, green: 0.23, blue: 0.46, alpha: 1.0)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: accentColor,
            .font: UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        ]

        navigationBar.tintColor = accentColor
        navigationBar.titleTextAttributes = titleAttributes

        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = titleAttributes

        if #available(iOS 26.0, *) {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
        }
        else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 1.0, alpha: 0.96)
            appearance.shadowColor = UIColor(red: 0.73, green: 0.69, blue: 0.82, alpha: 0.22)
        }

        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationBar.compactScrollEdgeAppearance = appearance
        }
    }
}
#endif
