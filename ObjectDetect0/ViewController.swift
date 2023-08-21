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
    
  private var previousIndexFingerCoordinates: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]

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
                    var thumbsUpHandsCount = 0
                    var indexFingerWigglingCount = 0
                    for observation in results {
                        if self.isHandInVictoryPosition(observation: observation) {
                            victoryHandsCount += 1
                        }
                        if self.isHandInThumbsUpPosition(observation: observation) {
                            thumbsUpHandsCount += 1
                        }
                        if self.isIndexFingerUpAndWiggling(observation: observation) {
                            indexFingerWigglingCount += 1
                        }
                    }
                    
                    // Post the number of victory hands detected
                    NotificationCenter.default.post(name: .numberOfVictoryHandsDetectedChanged, object: victoryHandsCount)
                    
                    // Post the number of thumbs up hands detected
                    NotificationCenter.default.post(name: .numberOfThumbsUpHandsDetectedChanged, object: thumbsUpHandsCount)
                    
                    // wiggle count
                    NotificationCenter.default.post(name: .numberOfIndexFingerWigglingDetectedChanged, object: indexFingerWigglingCount)
                    
                    // Post total number of hands detected
                    NotificationCenter.default.post(name: .numberOfHandsDetectedChanged, object: results.count)
                } else {
                    NotificationCenter.default.post(name: .numberOfVictoryHandsDetectedChanged, object: 0)
                    NotificationCenter.default.post(name: .numberOfHandsDetectedChanged, object: 0)
                    NotificationCenter.default.post(name: .numberOfThumbsUpHandsDetectedChanged, object: 0)
                    NotificationCenter.default.post(name: .numberOfIndexFingerWigglingDetectedChanged, object: 0)
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
    
    //notes:
    //hand palm must be facing camera
    //simple gestures like thumbs up we're all good
    private func calculateMCPToWristDistance(for fingerPoints: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint], mcpJoint: VNHumanHandPoseObservation.JointName, wristLocation: CGPoint) -> CGFloat? {
        guard let mcpLocation = fingerPoints[mcpJoint]?.location else {
            return nil
        }
        return distance(from: mcpLocation, to: wristLocation)
    }
    
    private func isFingerExtended(fingerTip: VNRecognizedPoint?, fingerPoints: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint], mcpJoint: VNHumanHandPoseObservation.JointName, wristLocation: CGPoint) -> Bool {
        guard let tipLocation = fingerTip?.location else {
            return false
        }
        
        guard let mcpToWristDistance = calculateMCPToWristDistance(for: fingerPoints, mcpJoint: mcpJoint, wristLocation: wristLocation) else {
            return false
        }
        
        let tipToWristDistance = distance(from: tipLocation, to: wristLocation)
        return tipToWristDistance > mcpToWristDistance
    }
    
    private func extendedFingerPositions(observation: VNHumanHandPoseObservation) -> [Bool]? {
        guard let thumbPoints = try? observation.recognizedPoints(.thumb),
              let indexPoints = try? observation.recognizedPoints(.indexFinger),
              let middlePoints = try? observation.recognizedPoints(.middleFinger),
              let ringPoints = try? observation.recognizedPoints(.ringFinger),
              let littlePoints = try? observation.recognizedPoints(.littleFinger),
              let wristPoints = try? observation.recognizedPoints(.all),
              let wrist = wristPoints[.wrist] else {
            return nil
        }

        let thumbExtended = isFingerExtended(fingerTip: thumbPoints[.thumbTip], fingerPoints: thumbPoints, mcpJoint: .thumbMP, wristLocation: wrist.location)
        let indexExtended = isFingerExtended(fingerTip: indexPoints[.indexTip], fingerPoints: indexPoints, mcpJoint: .indexMCP, wristLocation: wrist.location)
        let middleExtended = isFingerExtended(fingerTip: middlePoints[.middleTip], fingerPoints: middlePoints, mcpJoint: .middleMCP, wristLocation: wrist.location)
        let ringExtended = isFingerExtended(fingerTip: ringPoints[.ringTip], fingerPoints: ringPoints, mcpJoint: .ringMCP, wristLocation: wrist.location)
        let littleExtended = isFingerExtended(fingerTip: littlePoints[.littleTip], fingerPoints: littlePoints, mcpJoint: .littleMCP, wristLocation: wrist.location)
        
        return [thumbExtended, indexExtended, middleExtended, ringExtended, littleExtended]
    }

    private func isVictoryHandPose(fingerPositions: [Bool]) -> Bool {
        guard fingerPositions.count == 5 else { return false }

        let thumbExtended = fingerPositions[0]
        let indexExtended = fingerPositions[1]
        let middleExtended = fingerPositions[2]
        let ringExtended = fingerPositions[3]
        let littleExtended = fingerPositions[4]

        // Victory position is inferred if only the index and middle fingers are extended
        return indexExtended && middleExtended && !thumbExtended && !ringExtended && !littleExtended
    }
    
    private func isThumbsUpHandPose(fingerPositions: [Bool]) -> Bool {
        guard fingerPositions.count == 5 else { return false }

        let thumbExtended = fingerPositions[0]
        let indexExtended = fingerPositions[1]
        let middleExtended = fingerPositions[2]
        let ringExtended = fingerPositions[3]
        let littleExtended = fingerPositions[4]
        
//        print("thumb: ", thumbExtended)
//        print("index: ", indexExtended)
//        print("middle: ", middleExtended)
//        print("ring: ", ringExtended)
//        print("little: ", littleExtended)
//        print(">>>>>")

        //only thumb extended
        let res = !indexExtended && !middleExtended && thumbExtended && !ringExtended && !littleExtended
        return res
    }

    private func isHandInVictoryPosition(observation: VNHumanHandPoseObservation) -> Bool {
        guard let fingerPositions = extendedFingerPositions(observation: observation) else { return false }
        return isVictoryHandPose(fingerPositions: fingerPositions)
    }

    private func isHandInThumbsUpPosition(observation: VNHumanHandPoseObservation) -> Bool {
        guard let fingerPositions = extendedFingerPositions(observation: observation) else { return false }
        //(isThumbsUpHandPose(fingerPositions: fingerPositions))
        return isThumbsUpHandPose(fingerPositions: fingerPositions)
    }
    
    private func isIndexFingerUpAndWiggling(observation: VNHumanHandPoseObservation) -> Bool {
        guard let fingerPositions = extendedFingerPositions(observation: observation) else { return false }
        
        // Check if only the index finger is extended
        let indexExtended = fingerPositions[1]
        //print(indexExtended)
        //let onlyIndexFingerExtended = !fingerPositions[0] && indexExtended && !fingerPositions[2] && !fingerPositions[3] && !fingerPositions[4]
        
        // Check if the index finger is wiggling based on its tip's coordinates
        if let indexPoints = try? observation.recognizedPoints(.indexFinger),
           let indexTip = indexPoints[.indexTip]?.location {
            
            if let prevIndexTipLocation = previousIndexFingerCoordinates[.indexTip] {
                let distanceMoved = distance(from: prevIndexTipLocation, to: indexTip)
                print(distanceMoved)
                // You can adjust the threshold as per your requirement
                if distanceMoved > 0.1 {
                    previousIndexFingerCoordinates[.indexTip] = indexTip
                    print("fits wiggle criteria")
                    return true
                }
            }
            
            previousIndexFingerCoordinates[.indexTip] = indexTip
        }
        print("no wiggle")
        return false
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


