//
//  ViewController.swift
//  ObjectDetect0
//
//  Created by Qiwei on 8/1/23.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {

  // MARK: - Variables

  private var numberOfHandsDetected = 0
  private let videoDataOutput = AVCaptureVideoDataOutput()
  private let captureSession = AVCaptureSession()

  private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.

    addCameraInput()
    showCameraFeed()

    getCameraFrames()
    captureSession.startRunning()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    previewLayer.frame = view.frame
  }

  // MARK: - Helper Functions

  private func addCameraInput() {
    guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: .front).devices.first else {
      fatalError("No camera detected. Please use a real camera, not a simulator.")
    }

    // ⚠️ You should wrap this in a `do-catch` block, but this will be good enough for the demo.
    let cameraInput = try! AVCaptureDeviceInput(device: device)
    captureSession.addInput(cameraInput)
  }

  private func showCameraFeed() {
    previewLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(previewLayer)
    previewLayer.frame = view.frame
  }

  private func getCameraFrames() {
    videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString): NSNumber(value: kCVPixelFormatType_32BGRA)] as [String: Any]

    videoDataOutput.alwaysDiscardsLateVideoFrames = true
    // You do not want to process the frames on the Main Thread so we offload to another thread
    videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))

    captureSession.addOutput(videoDataOutput)

    guard let connection = videoDataOutput.connection(with: .video), connection.isVideoOrientationSupported else {
      return
    }

    connection.videoOrientation = .portrait
      
  }

    private func detectHands(image: CVPixelBuffer) {
        let handPoseRequest = VNDetectHumanHandPoseRequest { [weak self] vnRequest, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let results = vnRequest.results as? [VNHumanHandPoseObservation], !results.isEmpty {
                    let numberOfHands = results.count
                    NotificationCenter.default.post(name: .numberOfHandsDetectedChanged, object: numberOfHands)
                } else {
                    NotificationCenter.default.post(name: .numberOfHandsDetectedChanged, object: 0)
                }
            }
        }

        handPoseRequest.maximumHandCount = 2 // Set the maximum number of hands to detect

        let imageResultHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageResultHandler.perform([handPoseRequest])
    }

}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

    guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      debugPrint("Unable to get image from the sample buffer")
      return
    }

    detectHands(image: frame)
  }

}

