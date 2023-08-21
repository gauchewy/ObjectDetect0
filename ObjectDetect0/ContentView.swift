//
//  ContentView.swift
//  ObjectDetect0
//
//  Created by Qiwei on 8/1/23.
//

// TO DO OVERALL
// reduce flickering in victory hands after initally ok
// remove thumbs up, replace with wiggle fingers

import SwiftUI
import Foundation
import Combine

struct CameraView: UIViewControllerRepresentable {
    typealias UIViewControllerType = ViewController
    
    func makeUIViewController(context: Context) -> ViewController {
        let viewController = ViewController()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {

    }
}
struct ContentView: View {
    @State private var selectedOption = 0
    @State private var isTwoHandsDetected = false
    @State private var isVictoryPoseDetected = false
    @State private var isThumbsUpPoseDetected = false
    @State private var isWigglePoseDetected = false
    
    @State private var numberOfVictoryHands: Int = 0
    @State private var numberOfThumbsUpHands: Int = 0
    @State private var numberOfTotalHands: Int = 0
    @State private var numberOfWiggleHands: Int = 0
    
    @State private var twoHandsCancellable: AnyCancellable?
    @State private var victoryPoseCancellable: AnyCancellable?
    @State private var thumbsUpPoseCancellable: AnyCancellable?

    
    var menuTitle: String {
        switch selectedOption {
        case 0:
            return "Two Hands"
        case 1:
            return "Victory Pose"
        case 2:
            return "Thumbs Up"
        case 3:
            return "Wiggle"
        default:
            return "Choose Hand Pose"
        }
    }


    var body: some View {
        ZStack {
            Image("abe")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()

            // Conditions to display the black Rectangle based on option selected
            if (selectedOption == 0 && !isTwoHandsDetected) || (selectedOption == 1 && !isVictoryPoseDetected) ||
            (selectedOption == 2 && !isThumbsUpPoseDetected) || (selectedOption == 3 && !isWigglePoseDetected){
                Rectangle()
                    .fill(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack {
                Spacer()

                HStack {
                    Spacer()

                    CameraView()
                        .frame(width: UIScreen.main.bounds.width / 3, height: UIScreen.main.bounds.height / 4)
                        .background(
                            (selectedOption == 0 && isTwoHandsDetected) ||
                            (selectedOption == 1 && isVictoryPoseDetected) ||
                            (selectedOption == 2 && isThumbsUpPoseDetected) ||
                            (selectedOption == 3 && isWigglePoseDetected)
                            ? Color.clear : Color.black
                        )
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20).stroke(Color.green, lineWidth:
                                                                        (selectedOption == 0 && isTwoHandsDetected) ||
                                                                        (selectedOption == 1 && isVictoryPoseDetected) ||
                                                                        (selectedOption == 2 && isThumbsUpPoseDetected) ||
                                                                        (selectedOption == 3 && isWigglePoseDetected)
                                                                        ? 5 : 0)
                        )
                        .padding()
                }
            }

            VStack {
                Menu(menuTitle) {
                    Button(action: { selectedOption = 0 }) {
                        Text("Two Hands")
                            .font(.system(size: 18, weight: .bold))
                    }
                    Button(action: { selectedOption = 1 }) {
                        Text("Victory Pose")
                            .font(.system(size: 18, weight: .bold))
                    }
                    Button(action: { selectedOption = 2 }) {
                        Text("Thumbs Up")
                            .font(.system(size: 18, weight: .bold))
                    }
                    Button(action: { selectedOption = 3 }) {
                        Text("Wiggle")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .padding()
                .foregroundColor(Color.black)
                .background(Color.white)
                .cornerRadius(10)
                .padding(.top, 20)

                Spacer()
            }
        }
        //total hands
        .onReceive(NotificationCenter.default.publisher(for: .numberOfHandsDetectedChanged)) { notification in
            if selectedOption == 0, let numberOfHands = notification.object as? Int {
                if numberOfHands == 2 {
                    isTwoHandsDetected = true
                    twoHandsCancellable?.cancel()
                    twoHandsCancellable = AnyCancellable {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isTwoHandsDetected = false
                        }
                    }
                }
            }
        }
        //victory hands
        .onReceive(NotificationCenter.default.publisher(for: .numberOfVictoryHandsDetectedChanged)) { notification in
            if selectedOption == 1, let detectedVictoryHands = notification.object as? Int {
                numberOfVictoryHands = detectedVictoryHands
            }
        }

        .onReceive(NotificationCenter.default.publisher(for: .numberOfHandsDetectedChanged)) { notification in
            if selectedOption == 1, let detectedTotalHands = notification.object as? Int {
                numberOfTotalHands = detectedTotalHands
            }

            if numberOfTotalHands == 2 && numberOfVictoryHands >= 1 {
                isVictoryPoseDetected = true
                victoryPoseCancellable?.cancel()
                victoryPoseCancellable = AnyCancellable {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isVictoryPoseDetected = false
                    }
                }
            }
        }
        //thumbs up
        .onReceive(NotificationCenter.default.publisher(for: .numberOfThumbsUpHandsDetectedChanged)) { notification in
            if selectedOption == 2, let detectedVictoryHands = notification.object as? Int {
                numberOfThumbsUpHands = detectedVictoryHands
            }
        }

        .onReceive(NotificationCenter.default.publisher(for: .numberOfHandsDetectedChanged)) { notification in
            if selectedOption == 2, let detectedTotalHands = notification.object as? Int {
                numberOfTotalHands = detectedTotalHands
            }

            if numberOfTotalHands == 2 && numberOfThumbsUpHands >= 1 {
                isThumbsUpPoseDetected = true
                thumbsUpPoseCancellable?.cancel()
                thumbsUpPoseCancellable = AnyCancellable {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isThumbsUpPoseDetected = false
                    }
                }
            }
        }
    }

}


extension Notification.Name {
    static let numberOfHandsDetectedChanged = Notification.Name("numberOfHandsDetectedChanged")
}

extension NSNotification.Name {
    static let numberOfVictoryHandsDetectedChanged = NSNotification.Name("numberOfVictoryHandsDetectedChanged")
}

extension NSNotification.Name {
    static let numberOfThumbsUpHandsDetectedChanged = NSNotification.Name("numberOfThumbsUpHandsDetectedChanged")
}

extension Notification.Name {
    static let numberOfIndexFingerWigglingDetectedChanged = Notification.Name("numberOfIndexFingerWigglingDetectedChanged")
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
