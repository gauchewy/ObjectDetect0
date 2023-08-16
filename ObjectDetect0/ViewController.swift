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
                        }
                    }

                    // Post the number of victory hands detected
                    NotificationCenter.default.post(name: .numberOfVictoryHandsDetectedChanged, object: victoryHandsCount)
                    
                    // Post total number of hands detected
                    NotificationCenter.default.post(name: .numberOfHandsDetectedChanged, object: results.count)
                } else {
                    NotificationCenter.default.post(name: .numberOfVictoryHandsDetectedChanged, object: 0)
                    NotificationCenter.default.post(name: .numberOfHandsDetectedChanged, object: 0)
                }
            }
        }

        handPoseRequest.maximumHandCount = 2 // Set the maximum number of hands to detect

        let imageResultHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageResultHandler.perform([handPoseRequest])
    }

    
    private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        return sqrt(pow(point2.x - point1.x, 2) + pow(point2.y - point1.y, 2))
    }

    private func isHandInVictoryPosition(observation: VNHumanHandPoseObservation) -> Bool {
        guard let thumbPoints = try? observation.recognizedPoints(.thumb),
              let indexPoints = try? observation.recognizedPoints(.indexFinger),
              let middlePoints = try? observation.recognizedPoints(.middleFinger),
              let ringPoints = try? observation.recognizedPoints(.ringFinger),
              let littlePoints = try? observation.recognizedPoints(.littleFinger)
              //let wristPoint = try? observation.recognizedPoints(.all)[.wrist]
        else {
            return false
        }
        
        guard let wristPoints = try? observation.recognizedPoints(.all),
              let wrist = wristPoints[.wrist] else {
            return false
        }


        //notes:
        //hand palm must be facing camera
        //simple gestures like thumbs up we're all good
        func calculateMCPToWristDistance(for fingerPoints: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint], mcpJoint: VNHumanHandPoseObservation.JointName, wristLocation: CGPoint) -> CGFloat? {
            guard let mcpLocation = fingerPoints[mcpJoint]?.location else {
                return nil
            }
            return distance(from: mcpLocation, to: wristLocation)
        }


        func isFingerExtended(fingerTip: VNRecognizedPoint?, fingerPoints: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint], mcpJoint: VNHumanHandPoseObservation.JointName, wristLocation: CGPoint) -> Bool {
            guard let tipLocation = fingerTip?.location else {
                return false
            }
            
            guard let mcpToWristDistance = calculateMCPToWristDistance(for: fingerPoints, mcpJoint: mcpJoint, wristLocation: wristLocation) else {
                return false
            }
            
            let tipToWristDistance = distance(from: tipLocation, to: wristLocation)
            return tipToWristDistance > mcpToWristDistance
        }

        

        let thumbExtended = isFingerExtended(fingerTip: thumbPoints[.thumbTip], fingerPoints: thumbPoints, mcpJoint: .thumbMP, wristLocation: wrist.location)
        let indexExtended = isFingerExtended(fingerTip: indexPoints[.indexTip], fingerPoints: indexPoints, mcpJoint: .indexMCP, wristLocation: wrist.location)
        let middleExtended = isFingerExtended(fingerTip: middlePoints[.middleTip], fingerPoints: middlePoints, mcpJoint: .middleMCP, wristLocation: wrist.location)
        let ringExtended = isFingerExtended(fingerTip: ringPoints[.ringTip], fingerPoints: ringPoints, mcpJoint: .ringMCP, wristLocation: wrist.location)
        let littleExtended = isFingerExtended(fingerTip: littlePoints[.littleTip], fingerPoints: littlePoints, mcpJoint: .littleMCP, wristLocation: wrist.location)

        
        print("Thumb Points:", thumbExtended)
        print("Index Points:", indexExtended)
        print("Middle Points:", middleExtended)
        print("Ring Points:", ringExtended)
        print("Little Points:", littleExtended)
        print("____")

        // Victory position is inferred if only the index and middle fingers are extended
        let victoryDetected = indexExtended && middleExtended && !thumbExtended && !ringExtended && !littleExtended

        return victoryDetected
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

