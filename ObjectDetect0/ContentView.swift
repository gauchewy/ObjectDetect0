//
//  ContentView.swift
//  ObjectDetect0
//
//  Created by Qiwei on 8/1/23.
//

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
    @State private var numberOfVictoryHands: Int = 0
    @State private var numberOfTotalHands: Int = 0
    @State private var resetTimer: Timer?


    
    var menuTitle: String {
        switch selectedOption {
        case 0:
            return "Two Hands"
        case 1:
            return "Victory Pose"
        case 2:
            return "Option 3"
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
            if (selectedOption == 0 && !isTwoHandsDetected) || (selectedOption == 1 && !isVictoryPoseDetected) {
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
                            (selectedOption == 0 && isTwoHandsDetected) || (selectedOption == 1 && isVictoryPoseDetected) ? Color.clear : Color.black
                        )
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20).stroke(Color.green, lineWidth: (selectedOption == 0 && isTwoHandsDetected) || (selectedOption == 1 && isVictoryPoseDetected) ? 5 : 0)
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
                        Text("Option 3")
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
        //two hands
        .onReceive(NotificationCenter.default.publisher(for: .numberOfHandsDetectedChanged)) { notification in
            if selectedOption == 0, let numberOfHands = notification.object as? Int {
                isTwoHandsDetected = numberOfHands == 2
            }
        }
        //victoryhands
        .onReceive(NotificationCenter.default.publisher(for: .numberOfVictoryHandsDetectedChanged)) { notification in
            if selectedOption == 1,
               let detectedVictoryHands = notification.object as? Int {
                numberOfVictoryHands = detectedVictoryHands
            }
        }

        .onReceive(NotificationCenter.default.publisher(for: .numberOfHandsDetectedChanged)) { notification in
            if selectedOption == 1,
               let detectedTotalHands = notification.object as? Int {
                numberOfTotalHands = detectedTotalHands
            }

            isVictoryPoseDetected = numberOfTotalHands == 2 && numberOfVictoryHands >= 1
        }

    }

}


extension Notification.Name {
    static let numberOfHandsDetectedChanged = Notification.Name("numberOfHandsDetectedChanged")
}

extension NSNotification.Name {
    static let numberOfVictoryHandsDetectedChanged = NSNotification.Name("numberOfVictoryHandsDetectedChanged")
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
