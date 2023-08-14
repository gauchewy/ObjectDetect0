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
                    var victoryHandsCount = 0
                    for observation in results {
                        if self.isHandInVictoryPosition(observation: observation) {
                            victoryHandsCount += 1
                            print("victory hands count:", victoryHandsCount)
                        }
                    }

                    // Post the number of victory hands detected
                    NotificationCenter.default.post(name: .numberOfVictoryHandsDetectedChanged, object: victoryHandsCount)

                    // Post total number of hands detected
                    NotificationCenter.default.post(name: .numberOfHandsDetectedChanged, object: results.count)
                } else {
                    NotificationCenter.default.post(name: .numberOfHandsDetectedChanged, object: 0)
                }
            }
        }

        handPoseRequest.maximumHandCount = 2 // Set the maximum number of hands to detect

        let imageResultHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageResultHandler.perform([handPoseRequest])
    }
    
    private func isHandInVictoryPosition(observation: VNHumanHandPoseObservation) -> Bool {
        guard let thumbPoints = try? observation.recognizedPoints(.thumb),
              let indexPoints = try? observation.recognizedPoints(.indexFinger),
              let middlePoints = try? observation.recognizedPoints(.middleFinger),
              let ringPoints = try? observation.recognizedPoints(.ringFinger),
              let littlePoints = try? observation.recognizedPoints(.littleFinger) else {
            return false
        }
        
        let confidenceThreshold: Float = 0.3
        let extendedAngleThreshold: CGFloat = 100.0
        
        func isFingerExtended(joints: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint], tip: VNHumanHandPoseObservation.JointName, distal: VNHumanHandPoseObservation.JointName, proximal: VNHumanHandPoseObservation.JointName) -> Float {
            guard let tipPoint = joints[tip], let dip = joints[distal], let pip = joints[proximal],
                  tipPoint.confidence > confidenceThreshold, dip.confidence > confidenceThreshold, pip.confidence > confidenceThreshold else {
                return 0.0
            }
            let angle = calculateAngle(A: pip.location, B: dip.location, C: tipPoint.location)
            return Float(angle)
        }
        
        let thumbExtended = isFingerExtended(joints: thumbPoints, tip: .thumbTip, distal: .thumbIP, proximal: .thumbMP)
        let indexExtended = isFingerExtended(joints: indexPoints, tip: .indexTip, distal: .indexDIP, proximal: .indexPIP)
        let middleExtended = isFingerExtended(joints: middlePoints, tip: .middleTip, distal: .middleDIP, proximal: .middlePIP)
        let ringExtended = isFingerExtended(joints: ringPoints, tip: .ringTip, distal: .ringDIP, proximal: .ringPIP)
        let littleExtended = isFingerExtended(joints: littlePoints, tip: .littleTip, distal: .littleDIP, proximal: .littlePIP)
        
        print("thumb:", thumbExtended)
        print("index:", indexExtended)
        print("middle:", middleExtended)
        print("ring:", ringExtended)
        print("little:", littleExtended)
        
        // Victory position is inferred if only the index and middle fingers are extended
        //let victoryPoseRes = indexExtended && middleExtended && !thumbExtended && !ringExtended && !littleExtended
        return true
    }

    private func calculateAngle(A: CGPoint, B: CGPoint, C: CGPoint) -> CGFloat {
        let BA = CGPoint(x: A.x - B.x, y: A.y - B.y)
        let BC = CGPoint(x: C.x - B.x, y: C.y - B.y)
        
        let dotProduct = (BA.x * BC.x + BA.y * BC.y)
        let magnitudeOfBA = sqrt(BA.x*BA.x + BA.y*BA.y)
        let magnitudeOfBC = sqrt(BC.x*BC.x + BC.y*BC.y)
        let angle = acos(dotProduct / (magnitudeOfBA * magnitudeOfBC)) * (180.0 / CGFloat.pi)
        
        return angle
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

