import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
@preconcurrency import AVFoundation
@preconcurrency import AVFAudio
@preconcurrency import Speech
import CoreImage
#endif

// MARK: - Modèles Temps Réel du Moteur 100 % Natif « Viple Visio »

public struct NativeVisioPeer: Identifiable, Equatable, Sendable {
    public let slotId: UInt32
    public var email: String
    public var displayName: String
    public var avatarUrl: String?
    public var audioMuted: Bool
    public var videoEnabled: Bool
    public var isSpeaking: Bool
    #if canImport(UIKit)
    public var latestVideoFrame: UIImage?
    #endif

    public var id: UInt32 { slotId }

    public static func == (lhs: NativeVisioPeer, rhs: NativeVisioPeer) -> Bool {
        #if canImport(UIKit)
        return lhs.slotId == rhs.slotId
            && lhs.email == rhs.email
            && lhs.displayName == rhs.displayName
            && lhs.avatarUrl == rhs.avatarUrl
            && lhs.audioMuted == rhs.audioMuted
            && lhs.videoEnabled == rhs.videoEnabled
            && lhs.isSpeaking == rhs.isSpeaking
            && lhs.latestVideoFrame === rhs.latestVideoFrame
        #else
        return lhs.slotId == rhs.slotId
            && lhs.email == rhs.email
            && lhs.displayName == rhs.displayName
            && lhs.avatarUrl == rhs.avatarUrl
            && lhs.audioMuted == rhs.audioMuted
            && lhs.videoEnabled == rhs.videoEnabled
            && lhs.isSpeaking == rhs.isSpeaking
        #endif
    }
}

private struct VisioWirePeerDto: Decodable, Sendable {
    let slotId: UInt32
    let email: String?
    let displayName: String?
    let avatarUrl: String?
    let audioMuted: Bool?
    let videoEnabled: Bool?
}

public struct BetaVisioWhiteboardStroke: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let colorHex: String
    public var pointsX: [Double]
    public var pointsY: [Double]
}

public struct BetaVisioChatMessage: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let senderName: String
    public let text: String
    public let sentAt: Date
}

public struct BetaVisioFloatingEmoji: Identifiable, Equatable, Sendable {
    public let id: String
    public let emoji: String
    public let senderName: String
    public let createdAt: Date
}

private struct VisioWireControlEnvelope: Decodable, Sendable {
    let type: String
    let selfSlotId: UInt32?
    let slotId: UInt32?
    let email: String?
    let senderName: String?
    let eventKind: String?
    let payloadJson: String?
    let audioMuted: Bool?
    let videoEnabled: Bool?
    let peer: VisioWirePeerDto?
    let peers: [VisioWirePeerDto]?
}

#if canImport(UIKit)

// MARK: - Aperçu Caméra Locale 60 FPS Natif (AVCaptureVideoPreviewLayer — Zéro WebView)

public final class NativeCapturePreviewUIView: UIView {
    public override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    public var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }
}

public struct NativeCameraPreviewView: UIViewRepresentable {
    public let session: AVCaptureSession

    public init(session: AVCaptureSession) {
        self.session = session
    }

    public func makeUIView(context: Context) -> NativeCapturePreviewUIView {
        let view = NativeCapturePreviewUIView()
        view.backgroundColor = .black
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.session = session
        return view
    }

    public func updateUIView(_ uiView: NativeCapturePreviewUIView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
    }
}

// MARK: - Pipeline Audio Temps Réel Natif (AVAudioEngine 16 kHz Mono PCM)

private final class VisioAudioPipeline: @unchecked Sendable {
    private let lock = NSLock()
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var voiceEqNode: AVAudioUnitEQ?
    private var activeConverter: AVAudioConverter?
    private var activeSpeechRequest: SFSpeechAudioBufferRecognitionRequest?
    private let playbackFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    private let networkInt16Format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!

    private var isRunning: Bool = false
    private var isMuted: Bool = false
    private var pendingPlaybackBuffers: Int = 0

    func setMuted(_ muted: Bool) {
        lock.lock()
        isMuted = muted
        lock.unlock()
    }

    func setVoiceClarityEqEnabled(_ enabled: Bool) {
        lock.lock()
        let eq = voiceEqNode
        lock.unlock()
        eq?.bypass = !enabled
    }

    func setSpeechRecognitionRequest(_ req: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        activeSpeechRequest = req
        lock.unlock()
    }

    func setSpeakerphone(_ speakerOn: Bool) {
        let session = AVAudioSession.sharedInstance()
        try? session.overrideOutputAudioPort(speakerOn ? .speaker : .none)
    }

    func start(
        speakerphoneOn: Bool,
        onCapturedPacket: @escaping @Sendable (Data?, Float) -> Void
    ) {
        lock.lock()
        if isRunning {
            lock.unlock()
            return
        }
        lock.unlock()

        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions = speakerphoneOn
            ? [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
            : [.allowBluetoothHFP, .allowBluetoothA2DP]
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
        try? session.setPreferredIOBufferDuration(0.02)
        try? session.setActive(true, options: [])
        try? session.overrideOutputAudioPort(speakerOnPort(speakerphoneOn))

        let newEngine = AVAudioEngine()
        let newPlayer = AVAudioPlayerNode()
        let voiceEq = AVAudioUnitEQ(numberOfBands: 2)
        if voiceEq.bands.count >= 2 {
            voiceEq.bands[0].filterType = .highPass
            voiceEq.bands[0].frequency = 110
            voiceEq.bands[0].bypass = false
            voiceEq.bands[1].filterType = .parametric
            voiceEq.bands[1].frequency = 2600
            voiceEq.bands[1].bandwidth = 1.0
            voiceEq.bands[1].gain = 4.5
            voiceEq.bands[1].bypass = false
        }
        newEngine.attach(newPlayer)
        newEngine.attach(voiceEq)
        newEngine.connect(newPlayer, to: voiceEq, format: playbackFormat)
        newEngine.connect(voiceEq, to: newEngine.mainMixerNode, format: playbackFormat)

        let inputNode = newEngine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        if hwFormat.sampleRate > 0 && hwFormat.channelCount > 0,
           let converter = AVAudioConverter(from: hwFormat, to: networkInt16Format) {
            lock.lock()
            self.activeConverter = converter
            lock.unlock()

            inputNode.installTap(onBus: 0, bufferSize: 2048, format: hwFormat) { [weak self] pcmBuffer, _ in
                guard let self else { return }

                self.lock.lock()
                let currentlyMuted = self.isMuted
                let conv = self.activeConverter
                let speechReq = self.activeSpeechRequest
                self.lock.unlock()

                if currentlyMuted {
                    onCapturedPacket(nil, 0)
                    return
                }
                speechReq?.append(pcmBuffer)
                guard let conv else { return }

                let targetFmt = self.networkInt16Format
                let ratio = targetFmt.sampleRate / max(1.0, pcmBuffer.format.sampleRate)
                let outCapacity = AVAudioFrameCount(max(64, Int(Double(pcmBuffer.frameLength) * ratio) + 32))
                guard let converted = AVAudioPCMBuffer(pcmFormat: targetFmt, frameCapacity: outCapacity) else {
                    return
                }

                var suppliedInput = false
                var convErr: NSError?
                let status = conv.convert(to: converted, error: &convErr) { _, outStatus in
                    if suppliedInput {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    suppliedInput = true
                    outStatus.pointee = .haveData
                    return pcmBuffer
                }

                guard status != .error, convErr == nil,
                      converted.frameLength > 0,
                      let chPtr = converted.int16ChannelData?[0] else {
                    return
                }

                let sampleCount = Int(converted.frameLength)
                var sumSquares: Float = 0
                for i in 0..<sampleCount {
                    let norm = Float(chPtr[i]) / 32768.0
                    sumSquares += norm * norm
                }
                let rms = sqrt(sumSquares / Float(max(1, sampleCount)))
                let normalizedLevel = min(1.0, rms * 5.2)

                let byteCount = sampleCount * 2
                var packet = Data(capacity: 1 + byteCount)
                packet.append(0x01)
                packet.append(UnsafeBufferPointer(
                    start: UnsafeRawPointer(chPtr).assumingMemoryBound(to: UInt8.self),
                    count: byteCount
                ))
                onCapturedPacket(packet, normalizedLevel)
            }
        }

        do {
            newEngine.prepare()
            try newEngine.start()
            newPlayer.play()

            lock.lock()
            self.engine = newEngine
            self.playerNode = newPlayer
            self.voiceEqNode = voiceEq
            self.pendingPlaybackBuffers = 0
            self.isRunning = true
            lock.unlock()
        } catch {
            inputNode.removeTap(onBus: 0)
        }
    }

    private func speakerOnPort(_ speakerOn: Bool) -> AVAudioSession.PortOverride {
        speakerOn ? .speaker : .none
    }

    func enqueueRemotePcm16(from packet: Data, payloadOffset: Int = 5) -> Float {
        let byteLen = packet.count - payloadOffset
        let sampleCount = byteLen / 2
        guard sampleCount > 0 else { return 0 }

        lock.lock()
        guard isRunning, let player = playerNode, let eng = engine, eng.isRunning else {
            lock.unlock()
            return 0
        }
        // Protection anti-dérive de latence : si plus de 10 tampons (~420 ms) sont en attente, on jette la trame ancienne
        if pendingPlaybackBuffers > 10 {
            lock.unlock()
            return 0
        }
        lock.unlock()

        guard let outBuf = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: AVAudioFrameCount(sampleCount)),
              let dst = outBuf.floatChannelData?[0] else {
            return 0
        }
        outBuf.frameLength = AVAudioFrameCount(sampleCount)

        var sumSquares: Float = 0
        packet.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let ptr = base.advanced(by: payloadOffset)
            for i in 0..<sampleCount {
                let lo = UInt16(ptr[i * 2])
                let hi = UInt16(ptr[i * 2 + 1]) << 8
                let sample = Int16(bitPattern: lo | hi)
                let f = Float(sample) / 32768.0
                dst[i] = f
                sumSquares += f * f
            }
        }

        let rms = sqrt(sumSquares / Float(sampleCount))

        lock.lock()
        pendingPlaybackBuffers += 1
        lock.unlock()

        if !player.isPlaying {
            player.play()
        }
        player.scheduleBuffer(outBuf, completionCallbackType: .dataConsumed) { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.pendingPlaybackBuffers = max(0, self.pendingPlaybackBuffers - 1)
            self.lock.unlock()
        }

        return min(1.0, rms * 5.0)
    }

    func stop() {
        lock.lock()
        let currentEngine = engine
        let currentPlayer = playerNode
        engine = nil
        playerNode = nil
        voiceEqNode = nil
        activeConverter = nil
        activeSpeechRequest?.endAudio()
        activeSpeechRequest = nil
        isRunning = false
        pendingPlaybackBuffers = 0
        lock.unlock()

        currentEngine?.inputNode.removeTap(onBus: 0)
        currentPlayer?.stop()
        currentEngine?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

// MARK: - Pipeline Caméra Temps Réel Natif (AVCaptureSession + Encodage Matériel CoreImage)

private final class VisioCameraPipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let captureSession = AVCaptureSession()
    private let cameraQueue = DispatchQueue(label: "com.viplemail.visio.camera", qos: .userInteractive)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let stateLock = NSLock()

    private var currentPosition: AVCaptureDevice.Position = .front
    private var lastFrameSentTime: CFAbsoluteTime = 0
    private var isEncodingFrame: Bool = false
    private var filterMode: String = "none"
    private var lowBandwidth: Bool = false
    private var onEncodedVideoPacket: (@Sendable (Data) -> Void)?

    func updateTuning(filterMode: String, lowBandwidth: Bool) {
        stateLock.lock()
        self.filterMode = filterMode
        self.lowBandwidth = lowBandwidth
        stateLock.unlock()
    }

    func start(
        position: AVCaptureDevice.Position,
        onVideoPacket: @escaping @Sendable (Data) -> Void
    ) {
        stateLock.lock()
        self.currentPosition = position
        self.onEncodedVideoPacket = onVideoPacket
        stateLock.unlock()

        cameraQueue.async { [weak self] in
            guard let self else { return }
            self.configureSessionLocked(for: position)
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    func switchPosition(to position: AVCaptureDevice.Position) {
        stateLock.lock()
        self.currentPosition = position
        stateLock.unlock()

        cameraQueue.async { [weak self] in
            guard let self else { return }
            self.configureSessionLocked(for: position)
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    func stop() {
        stateLock.lock()
        self.onEncodedVideoPacket = nil
        stateLock.unlock()

        cameraQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            self.captureSession.beginConfiguration()
            for input in self.captureSession.inputs {
                self.captureSession.removeInput(input)
            }
            for output in self.captureSession.outputs {
                self.captureSession.removeOutput(output)
            }
            self.captureSession.commitConfiguration()
        }
    }

    private func configureSessionLocked(for position: AVCaptureDevice.Position) {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if captureSession.canSetSessionPreset(.vga640x480) {
            captureSession.sessionPreset = .vga640x480
        }

        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let deviceInput = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(deviceInput) else {
            return
        }
        captureSession.addInput(deviceInput)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        if let conn = videoOutput.connection(with: .video) {
            if conn.isVideoRotationAngleSupported(90) {
                conn.videoRotationAngle = 90
            }
            if conn.isVideoMirroringSupported {
                conn.automaticallyAdjustsVideoMirroring = false
                conn.isVideoMirrored = (position == .front)
            }
        }
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CFAbsoluteTimeGetCurrent()

        stateLock.lock()
        let minInterval = lowBandwidth ? 0.16 : 0.072
        let activeFilter = filterMode
        let isEco = lowBandwidth
        if isEncodingFrame || (now - lastFrameSentTime) < minInterval {
            stateLock.unlock()
            return
        }
        guard let callback = onEncodedVideoPacket else {
            stateLock.unlock()
            return
        }
        isEncodingFrame = true
        lastFrameSentTime = now
        stateLock.unlock()

        defer {
            stateLock.lock()
            isEncodingFrame = false
            stateLock.unlock()
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        let targetMaxSide: CGFloat = isEco ? 240 : 400
        let maxSide = max(extent.width, extent.height)
        if maxSide > targetMaxSide {
            let scale = targetMaxSide / maxSide
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        let croppedExtent = ciImage.extent
        switch activeFilter {
        case "mono":
            if let f = CIFilter(name: "CIPhotoEffectNoir") {
                f.setValue(ciImage, forKey: kCIInputImageKey)
                if let out = f.outputImage { ciImage = out.cropped(to: croppedExtent) }
            }
        case "warm":
            if let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(ciImage, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: 5000, y: 0), forKey: "inputTargetNeutral")
                if let out = f.outputImage { ciImage = out.cropped(to: croppedExtent) }
            }
        case "studio":
            if let f = CIFilter(name: "CIColorControls") {
                f.setValue(ciImage, forKey: kCIInputImageKey)
                f.setValue(1.12, forKey: kCIInputContrastKey)
                f.setValue(0.04, forKey: kCIInputBrightnessKey)
                f.setValue(1.15, forKey: kCIInputSaturationKey)
                if let out = f.outputImage { ciImage = out.cropped(to: croppedExtent) }
            }
        case "blur":
            if let f = CIFilter(name: "CIGaussianBlur") {
                f.setValue(ciImage, forKey: kCIInputImageKey)
                f.setValue(6.0, forKey: kCIInputRadiusKey)
                if let out = f.outputImage { ciImage = out.cropped(to: croppedExtent) }
            }
        default:
            break
        }

        guard let cgImg = ciContext.createCGImage(ciImage, from: croppedExtent),
              let jpegData = UIImage(cgImage: cgImg).jpegData(compressionQuality: isEco ? 0.34 : 0.45) else {
            return
        }

        var packet = Data(capacity: 1 + jpegData.count)
        packet.append(0x02)
        packet.append(jpegData)
        callback(packet)
    }
}

#endif

// MARK: - Contrôleur Principal Observable « NativeVipleVisioEngine » (100 % SwiftUI Natif)

@MainActor
public final class NativeVipleVisioEngine: ObservableObject {
    public enum ConnectionPhase: Equatable, Sendable {
        case connecting
        case connected
        case reconnecting
        case ended
    }

    @Published public private(set) var phase: ConnectionPhase = .connecting
    @Published public private(set) var peers: [NativeVisioPeer] = []
    @Published public private(set) var isMuted: Bool = false
    @Published public private(set) var isVideoEnabled: Bool
    @Published public private(set) var isUsingFrontCamera: Bool = true
    @Published public private(set) var isSpeakerphoneOn: Bool = true
    @Published public private(set) var localVoiceLevel: CGFloat = 0
    @Published public private(set) var elapsedSeconds: Int = 0
    @Published public private(set) var micPermissionDenied: Bool = false
    @Published public private(set) var cameraPermissionDenied: Bool = false

    // --- Extensions Temps Réel Studio Pro Beta (#061..#070) ---
    @Published public var whiteboardStrokes: [BetaVisioWhiteboardStroke] = []
    @Published public var liveSubtitleText: String = ""
    @Published public var isAutoSpeechCaptionsActive: Bool = false
    @Published public var floatingEmojis: [BetaVisioFloatingEmoji] = []
    @Published public var raisedHands: Set<String> = []
    @Published public var inCallChatMessages: [BetaVisioChatMessage] = []
    @Published public var activeCameraFilter: String = "none"
    @Published public var lowBandwidthEcoMode: Bool = false
    @Published public var measuredRttMs: Int = 18
    @Published public var estimatedBitrateKbps: Int = 112
    @Published public var sharedTimeboxEnd: Date? = nil
    @Published public var callMeetingNotes: [String] = []
    private var lastPingSentAt: Date = Date()
    #if canImport(UIKit)
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var speechRecognitionTask: SFSpeechRecognitionTask?
    #endif

    public let roomCode: String
    public let localEmail: String
    public let localDisplayName: String
    public let isDirectOneToOneCall: Bool

    private var selfSlotId: UInt32 = 0
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?
    private var tickerLoopTask: Task<Void, Never>?
    private var isStoppedManually: Bool = false
    private var lastSpokeAtBySlot: [UInt32: Date] = [:]
    public var onRemotePeerHangup: (() -> Void)?

    #if canImport(UIKit)
    private let audioPipeline = VisioAudioPipeline()
    private let cameraPipeline = VisioCameraPipeline()

    public var localCaptureSession: AVCaptureSession {
        cameraPipeline.captureSession
    }
    #endif

    public init(
        roomCode: String,
        localEmail: String,
        localDisplayName: String,
        initialAudioOnly: Bool,
        isDirectOneToOneCall: Bool
    ) {
        self.roomCode = roomCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.localEmail = localEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.localDisplayName = localDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isVideoEnabled = !initialAudioOnly
        self.isDirectOneToOneCall = isDirectOneToOneCall
        self.isSpeakerphoneOn = true
    }

    public var formattedDuration: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        if mins >= 60 {
            let hrs = mins / 60
            let remMins = mins % 60
            return String(format: "%d:%02d:%02d", hrs, remMins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }

    public func start() async {
        guard !isStoppedManually else { return }

        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = true
        let micGranted = await AVAudioApplication.requestRecordPermission()
        self.micPermissionDenied = !micGranted

        if isVideoEnabled {
            let camStatus = AVCaptureDevice.authorizationStatus(for: .video)
            let camGranted: Bool
            if camStatus == .authorized {
                camGranted = true
            } else if camStatus == .notDetermined {
                camGranted = await AVCaptureDevice.requestAccess(for: .video)
            } else {
                camGranted = false
            }
            self.cameraPermissionDenied = !camGranted
            if !camGranted {
                self.isVideoEnabled = false
            }
        }
        #endif

        connectWebSocket()

        #if canImport(UIKit)
        if !micPermissionDenied {
            startLocalAudioCapture()
        }
        if isVideoEnabled && !cameraPermissionDenied {
            startLocalCameraCapture()
        }
        #endif

        startTickerLoopIfNeeded()
    }

    public func toggleMute() {
        isMuted.toggle()
        if isMuted {
            localVoiceLevel = 0
        }
        #if canImport(UIKit)
        audioPipeline.setMuted(isMuted)
        #endif
        sendMediaStateUpdate()
    }

    public func toggleSpeakerphone() {
        isSpeakerphoneOn.toggle()
        #if canImport(UIKit)
        audioPipeline.setSpeakerphone(isSpeakerphoneOn)
        #endif
    }

    public func toggleVideo() async {
        if isVideoEnabled {
            isVideoEnabled = false
            #if canImport(UIKit)
            cameraPipeline.stop()
            #endif
            sendMediaStateUpdate()
        } else {
            #if canImport(UIKit)
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            let granted: Bool
            if status == .authorized {
                granted = true
            } else if status == .notDetermined {
                granted = await AVCaptureDevice.requestAccess(for: .video)
            } else {
                granted = false
            }
            cameraPermissionDenied = !granted
            guard granted else { return }
            isVideoEnabled = true
            startLocalCameraCapture()
            sendMediaStateUpdate()
            #endif
        }
    }

    public func flipCamera() {
        guard isVideoEnabled else { return }
        isUsingFrontCamera.toggle()
        #if canImport(UIKit)
        cameraPipeline.switchPosition(to: isUsingFrontCamera ? .front : .back)
        #endif
    }

    public func disconnect(sendHangupSignal: Bool = true) {
        guard !isStoppedManually else { return }
        isStoppedManually = true
        phase = .ended

        if sendHangupSignal, let ws = webSocketTask {
            let hangupJson = #"{"type":"hangup"}"#
            ws.send(.string(hangupJson)) { _ in }
        }

        receiveLoopTask?.cancel()
        receiveLoopTask = nil
        tickerLoopTask?.cancel()
        tickerLoopTask = nil

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = false
        speechRecognitionTask?.cancel()
        speechRecognitionTask = nil
        isAutoSpeechCaptionsActive = false
        cameraPipeline.stop()
        audioPipeline.stop()
        #endif
    }

    // MARK: - Connexion WebSocket Temps Réel (wss://mail.viplemail.fr/ws/visio)

    private func connectWebSocket() {
        guard !isStoppedManually else { return }

        var comps = URLComponents()
        comps.scheme = "wss"
        comps.host = "mail.viplemail.fr"
        comps.path = "/ws/visio"
        comps.queryItems = [
            URLQueryItem(name: "room", value: roomCode),
            URLQueryItem(name: "email", value: localEmail.isEmpty ? "invite@viplemail.fr" : localEmail),
            URLQueryItem(name: "name", value: localDisplayName.isEmpty ? "Utilisateur Viple" : localDisplayName),
            URLQueryItem(name: "mode", value: isVideoEnabled ? "video" : "audio")
        ]

        guard let wsUrl = comps.url else { return }

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        let task = URLSession.shared.webSocketTask(with: wsUrl)
        task.maximumMessageSize = 512 * 1024
        self.webSocketTask = task
        task.resume()

        receiveLoopTask?.cancel()
        receiveLoopTask = Task { [weak self] in
            await self?.runReceiveLoop(for: task)
        }
    }

    private func runReceiveLoop(for task: URLSessionWebSocketTask) async {
        while !Task.isCancelled && !isStoppedManually {
            do {
                let message = try await task.receive()
                if phase != .connected {
                    phase = .connected
                }
                switch message {
                case .string(let text):
                    handleIncomingControlJson(text)
                case .data(let data):
                    handleIncomingMediaPacket(data)
                @unknown default:
                    break
                }
            } catch {
                if Task.isCancelled || isStoppedManually {
                    return
                }
                phase = .reconnecting
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if !Task.isCancelled && !isStoppedManually {
                    connectWebSocket()
                }
                return
            }
        }
    }

    private func handleIncomingControlJson(_ jsonText: String) {
        guard let data = jsonText.data(using: .utf8),
              let env = try? JSONDecoder().decode(VisioWireControlEnvelope.self, from: data) else {
            return
        }

        switch env.type {
        case "welcome":
            phase = .connected
            if let sid = env.selfSlotId {
                self.selfSlotId = sid
            }
            if let wirePeers = env.peers {
                var updated: [NativeVisioPeer] = []
                for wp in wirePeers where wp.slotId != selfSlotId {
                    let existing = peers.first(where: { $0.slotId == wp.slotId })
                    #if canImport(UIKit)
                    let prevFrame = existing?.latestVideoFrame
                    updated.append(NativeVisioPeer(
                        slotId: wp.slotId,
                        email: wp.email ?? "",
                        displayName: wp.displayName ?? "Participant",
                        avatarUrl: wp.avatarUrl,
                        audioMuted: wp.audioMuted ?? false,
                        videoEnabled: wp.videoEnabled ?? false,
                        isSpeaking: false,
                        latestVideoFrame: prevFrame
                    ))
                    #else
                    updated.append(NativeVisioPeer(
                        slotId: wp.slotId,
                        email: wp.email ?? "",
                        displayName: wp.displayName ?? "Participant",
                        avatarUrl: wp.avatarUrl,
                        audioMuted: wp.audioMuted ?? false,
                        videoEnabled: wp.videoEnabled ?? false,
                        isSpeaking: false
                    ))
                    #endif
                }
                self.peers = updated.sorted { $0.slotId < $1.slotId }
            }
            sendMediaStateUpdate()

        case "peer_joined":
            guard let wp = env.peer, wp.slotId != selfSlotId else { return }
            if let idx = peers.firstIndex(where: { $0.slotId == wp.slotId }) {
                peers[idx].email = wp.email ?? peers[idx].email
                peers[idx].displayName = wp.displayName ?? peers[idx].displayName
                peers[idx].avatarUrl = wp.avatarUrl ?? peers[idx].avatarUrl
                peers[idx].audioMuted = wp.audioMuted ?? false
                peers[idx].videoEnabled = wp.videoEnabled ?? false
            } else {
                #if canImport(UIKit)
                let newPeer = NativeVisioPeer(
                    slotId: wp.slotId,
                    email: wp.email ?? "",
                    displayName: wp.displayName ?? "Participant",
                    avatarUrl: wp.avatarUrl,
                    audioMuted: wp.audioMuted ?? false,
                    videoEnabled: wp.videoEnabled ?? false,
                    isSpeaking: false,
                    latestVideoFrame: nil
                )
                #else
                let newPeer = NativeVisioPeer(
                    slotId: wp.slotId,
                    email: wp.email ?? "",
                    displayName: wp.displayName ?? "Participant",
                    avatarUrl: wp.avatarUrl,
                    audioMuted: wp.audioMuted ?? false,
                    videoEnabled: wp.videoEnabled ?? false,
                    isSpeaking: false
                )
                #endif
                peers.append(newPeer)
                peers.sort { $0.slotId < $1.slotId }
            }

        case "peer_media_state":
            guard let sid = env.slotId, let idx = peers.firstIndex(where: { $0.slotId == sid }) else { return }
            if let am = env.audioMuted {
                peers[idx].audioMuted = am
                if am {
                    peers[idx].isSpeaking = false
                }
            }
            if let ve = env.videoEnabled {
                peers[idx].videoEnabled = ve
                #if canImport(UIKit)
                if !ve {
                    peers[idx].latestVideoFrame = nil
                }
                #endif
            }

        case "peer_left":
            if let sid = env.slotId {
                peers.removeAll { $0.slotId == sid }
                lastSpokeAtBySlot.removeValue(forKey: sid)
            }

        case "peer_hangup":
            if let sid = env.slotId {
                peers.removeAll { $0.slotId == sid }
                lastSpokeAtBySlot.removeValue(forKey: sid)
            }
            if isDirectOneToOneCall && peers.isEmpty {
                onRemotePeerHangup?()
            }

        case "pong":
            measuredRttMs = max(4, Int(Date().timeIntervalSince(lastPingSentAt) * 1000))

        case "room_event":
            handleRoomEvent(kind: env.eventKind ?? "", sender: env.senderName ?? "Participant", rawPayload: env.payloadJson ?? "")

        default:
            break
        }
    }

    public func broadcastRoomEvent(kind: String, payloadObject: [String: Any]) {
        guard let ws = webSocketTask,
              let payloadData = try? JSONSerialization.data(withJSONObject: payloadObject),
              let payloadStr = String(data: payloadData, encoding: .utf8) else { return }
        let msg = #"{"type":"room_event","eventKind":"\#(kind)","payload":\#(payloadStr)}"#
        ws.send(.string(msg)) { _ in }
    }

    public func applyVideoFilterAndEco(filter: String, eco: Bool) {
        activeCameraFilter = filter
        lowBandwidthEcoMode = eco
        estimatedBitrateKbps = eco ? 48 : (isVideoEnabled ? 145 : 32)
        #if canImport(UIKit)
        cameraPipeline.updateTuning(filterMode: filter, lowBandwidth: eco)
        #endif
    }

    public func sendInCallChat(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let entry = BetaVisioChatMessage(id: UUID().uuidString, senderName: localDisplayName, text: clean, sentAt: Date())
        inCallChatMessages.append(entry)
        broadcastRoomEvent(kind: "chat", payloadObject: ["text": clean])
    }

    public func sendFloatingReaction(_ emoji: String) {
        let item = BetaVisioFloatingEmoji(id: UUID().uuidString, emoji: emoji, senderName: localDisplayName, createdAt: Date())
        floatingEmojis.append(item)
        if emoji == "✋" {
            if raisedHands.contains(localDisplayName) { raisedHands.remove(localDisplayName) }
            else { raisedHands.insert(localDisplayName) }
        }
        broadcastRoomEvent(kind: "reaction", payloadObject: ["emoji": emoji])
    }

    public func addWhiteboardStroke(_ stroke: BetaVisioWhiteboardStroke) {
        whiteboardStrokes.append(stroke)
        broadcastRoomEvent(kind: "wb_stroke", payloadObject: [
            "id": stroke.id,
            "colorHex": stroke.colorHex,
            "x": stroke.pointsX,
            "y": stroke.pointsY
        ])
    }

    public func clearWhiteboard() {
        whiteboardStrokes.removeAll()
        broadcastRoomEvent(kind: "wb_clear", payloadObject: [:])
    }

    public func broadcastSubtitle(_ line: String) {
        liveSubtitleText = "\(localDisplayName) : \(line)"
        broadcastRoomEvent(kind: "caption", payloadObject: ["line": line])
    }

    public func setVoiceClarityBoost(_ enabled: Bool) {
        #if canImport(UIKit)
        audioPipeline.setVoiceClarityEqEnabled(enabled)
        #endif
    }

    public func toggleAutoSpeechCaptions() {
        #if canImport(UIKit)
        if isAutoSpeechCaptionsActive {
            speechRecognitionTask?.cancel()
            speechRecognitionTask = nil
            audioPipeline.setSpeechRecognitionRequest(nil)
            isAutoSpeechCaptionsActive = false
            return
        }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self, status == .authorized, let recognizer = self.speechRecognizer, recognizer.isAvailable else {
                    return
                }
                let req = SFSpeechAudioBufferRecognitionRequest()
                req.shouldReportPartialResults = true
                self.audioPipeline.setSpeechRecognitionRequest(req)
                self.isAutoSpeechCaptionsActive = true
                self.speechRecognitionTask = recognizer.recognitionTask(with: req) { [weak self] result, error in
                    let latestSegment = result?.bestTranscription.formattedString.suffix(90).description
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let seg = latestSegment, !seg.isEmpty {
                            self.broadcastSubtitle(seg)
                        }
                        if error != nil {
                            self.isAutoSpeechCaptionsActive = false
                        }
                    }
                }
            }
        }
        #endif
    }

    public func startSharedTimebox(minutes: Int) {
        let end = Date().addingTimeInterval(Double(minutes * 60))
        sharedTimeboxEnd = end
        broadcastRoomEvent(kind: "timebox", payloadObject: ["endEpoch": end.timeIntervalSince1970])
    }

    private func handleRoomEvent(kind: String, sender: String, rawPayload: String) {
        guard let d = rawPayload.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return }
        switch kind {
        case "chat":
            if let txt = dict["text"] as? String {
                inCallChatMessages.append(BetaVisioChatMessage(id: UUID().uuidString, senderName: sender, text: txt, sentAt: Date()))
            }
        case "reaction":
            if let em = dict["emoji"] as? String {
                floatingEmojis.append(BetaVisioFloatingEmoji(id: UUID().uuidString, emoji: em, senderName: sender, createdAt: Date()))
                if em == "✋" {
                    if raisedHands.contains(sender) { raisedHands.remove(sender) }
                    else { raisedHands.insert(sender) }
                }
            }
        case "wb_stroke":
            if let id = dict["id"] as? String,
               let col = dict["colorHex"] as? String,
               let xs = dict["x"] as? [Double],
               let ys = dict["y"] as? [Double] {
                whiteboardStrokes.append(BetaVisioWhiteboardStroke(id: id, colorHex: col, pointsX: xs, pointsY: ys))
            }
        case "wb_clear":
            whiteboardStrokes.removeAll()
        case "caption":
            if let line = dict["line"] as? String {
                liveSubtitleText = "\(sender) : \(line)"
            }
        case "timebox":
            if let ep = dict["endEpoch"] as? Double {
                sharedTimeboxEnd = Date(timeIntervalSince1970: ep)
            }
        default:
            break
        }
    }

    private func handleIncomingMediaPacket(_ packet: Data) {
        guard packet.count > 5 else { return }
        let kind = packet[0]
        let senderSlot = UInt32(packet[1])
            | (UInt32(packet[2]) << 8)
            | (UInt32(packet[3]) << 16)
            | (UInt32(packet[4]) << 24)

        #if canImport(UIKit)
        if kind == 0x01 {
            let remoteLevel = audioPipeline.enqueueRemotePcm16(from: packet, payloadOffset: 5)
            if remoteLevel > 0.06, let idx = peers.firstIndex(where: { $0.slotId == senderSlot }) {
                lastSpokeAtBySlot[senderSlot] = Date()
                if !peers[idx].isSpeaking {
                    peers[idx].isSpeaking = true
                }
            }
        } else if kind == 0x02 {
            let jpegSlice = packet.subdata(in: 5..<packet.count)
            guard let img = UIImage(data: jpegSlice) else { return }
            if let idx = peers.firstIndex(where: { $0.slotId == senderSlot }) {
                peers[idx].latestVideoFrame = img
                if !peers[idx].videoEnabled {
                    peers[idx].videoEnabled = true
                }
            }
        }
        #endif
    }

    #if canImport(UIKit)
    private func startLocalAudioCapture() {
        audioPipeline.setMuted(isMuted)
        audioPipeline.start(speakerphoneOn: isSpeakerphoneOn) { [weak self] packet, rmsLevel in
            Task { @MainActor [weak self] in
                guard let self, !self.isStoppedManually else { return }
                self.localVoiceLevel = CGFloat(rmsLevel)
                if let packet, !self.isMuted, let ws = self.webSocketTask {
                    ws.send(.data(packet)) { _ in }
                }
            }
        }
    }

    private func startLocalCameraCapture() {
        cameraPipeline.start(position: isUsingFrontCamera ? .front : .back) { [weak self] videoPacket in
            Task { @MainActor [weak self] in
                guard let self, !self.isStoppedManually, self.isVideoEnabled, let ws = self.webSocketTask else { return }
                ws.send(.data(videoPacket)) { _ in }
            }
        }
    }
    #endif

    private func sendMediaStateUpdate() {
        guard let ws = webSocketTask else { return }
        let msg = #"{"type":"media_state","audioMuted":\#(isMuted ? "true" : "false"),"videoEnabled":\#(isVideoEnabled ? "true" : "false")}"#
        ws.send(.string(msg)) { _ in }
    }

    private func startTickerLoopIfNeeded() {
        guard tickerLoopTask == nil else { return }
        tickerLoopTask = Task { [weak self] in
            var tickCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, !self.isStoppedManually else { break }
                tickCount += 1

                if tickCount % 2 == 0 && !self.peers.isEmpty {
                    self.elapsedSeconds += 1
                }

                // Extinction fluide de l'indicateur de parole des pairs après 600 ms de silence
                let now = Date()
                for idx in self.peers.indices where self.peers[idx].isSpeaking {
                    let sid = self.peers[idx].slotId
                    if let last = self.lastSpokeAtBySlot[sid], now.timeIntervalSince(last) > 0.6 {
                        self.peers[idx].isSpeaking = false
                    }
                }

                // Keepalive applicatif toutes les 15 secondes + purge des émojis flottants anciens
                self.floatingEmojis.removeAll { now.timeIntervalSince($0.createdAt) > 3.2 }
                if tickCount % 30 == 0, let ws = self.webSocketTask {
                    self.lastPingSentAt = Date()
                    ws.send(.string(#"{"type":"ping"}"#)) { _ in }
                }
            }
        }
    }
}
