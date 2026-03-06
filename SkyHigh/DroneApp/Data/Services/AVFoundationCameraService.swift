//
//  AVFoundationCameraService.swift
//  SkyHigh - DroneApp
//
//  후면 카메라 720p 캡처 → VideoToolbox H.264 압축 → Data 스트리밍

import AVFoundation
import VideoToolbox
import RxSwift
import RxRelay

final class AVFoundationCameraService: NSObject, CameraService {

    // MARK: - Session
    let captureSession = AVCaptureSession()   // DroneContainer에서 previewLayer 연결용으로 접근
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "com.skyhigh.camera.session")
    private let compressionQueue = DispatchQueue(label: "com.skyhigh.camera.compress")

    // MARK: - VideoToolbox
    private var compressionSession: VTCompressionSession?

    // MARK: - Relay
    private let frameRelay = PublishRelay<Data>()
    var frameStream: Observable<Data> { frameRelay.asObservable() }

    // MARK: - CameraService

    func startCapture() {
        sessionQueue.async { [weak self] in
            self?.setupSession()
            self?.setupCompressionSession()
            self?.captureSession.startRunning()
        }
    }

    func stopCapture() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            if let session = self?.compressionSession {
                VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
                VTCompressionSessionInvalidate(session)
                self?.compressionSession = nil
            }
        }
    }

    // MARK: - Setup

    private func setupSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720  // 720p

        // 후면 카메라
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        // 비디오 출력
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.setSampleBufferDelegate(self, queue: compressionQueue)
        output.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.connection(with: .video)?.videoRotationAngle = 90
        }
        videoOutput = output

        captureSession.commitConfiguration()
    }

    private func setupCompressionSession() {
        var session: VTCompressionSession?
        VTCompressionSessionCreate(
            allocator: nil,
            width: 1280,
            height: 720,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        guard let session else { return }

        // 설정
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel,
                             value: kVTProfileLevel_H264_Baseline_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate,
                             value: 1_500_000 as CFNumber)  // 1.5Mbps
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate,
                             value: 30 as CFNumber)
        VTCompressionSessionPrepareToEncodeFrames(session)

        compressionSession = session
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension AVFoundationCameraService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let compressionSession,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        VTCompressionSessionEncodeFrame(
            compressionSession,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: .invalid,
            frameProperties: nil,
            infoFlagsOut: nil
        ) { [weak self] status, _, sampleBuffer in
            guard status == noErr, let sampleBuffer else { return }
            if let data = sampleBuffer.toData() {
                self?.frameRelay.accept(data)
            }
        }
    }
}

// MARK: - CMSampleBuffer Extension

private extension CMSampleBuffer {
    func toData() -> Data? {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(self) else { return nil }
        var length = 0
        var dataPointer: UnsafeMutablePointer<CChar>?
        guard CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0,
                                          lengthAtOffsetOut: nil,
                                          totalLengthOut: &length,
                                          dataPointerOut: &dataPointer) == noErr,
              let pointer = dataPointer else { return nil }
        return Data(bytes: pointer, count: length)
    }
}
