//
//  ContentView.swift
//  ObjectDetect0
//
//  Created by Qiwei on 8/1/23.
//

import SwiftUI

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
    @State private var isTwoHandsDetected = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack {
                Image("abe")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                Spacer()
            }
            .padding()

            if isTwoHandsDetected {
                Rectangle()
                    .fill(Color.clear)
                    
            } else {
                Rectangle()
                    .fill(Color.black)
            }
            
            Spacer()
            
            CameraView()
                .frame(width: UIScreen.main.bounds.width / 3, height: UIScreen.main.bounds.height / 4)
                .background(isTwoHandsDetected ? Color.clear : Color.black)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.green, lineWidth: isTwoHandsDetected ? 5 : 0))
                .padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: .numberOfHandsDetectedChanged)) { notification in
            if let numberOfHands = notification.object as? Int {
                isTwoHandsDetected = numberOfHands == 2
            }
        }
    }
}


extension Notification.Name {
    static let numberOfHandsDetectedChanged = Notification.Name("numberOfHandsDetectedChanged")
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
