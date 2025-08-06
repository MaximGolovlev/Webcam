//
//  CallView.swift
//  CallExample
//
//  Created by Maxim Golovlev on 06.08.2025.
//

import SwiftUI
import WebRTC

struct CallView: View {
    @StateObject private var viewModel = CallViewModel()
    
    var body: some View {
        callLayer
    }
    
    var callLayer: some View {
        ZStack {
            // Удаленное видео (полный экран)
            if let remoteView = viewModel.remoteVideoView {
                VideoView(rtcVideoView: remoteView)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Локальное видео (маленький превью)
            if let localView = viewModel.localVideoView {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VideoView(rtcVideoView: localView)
                            .frame(width: 100, height: 150)
                            .cornerRadius(8)
                            .padding()
                    }
                }
            }
            
            // Кнопка вызова
            VStack {
                Spacer()
                Button(action: {
                    viewModel.toggleCall()
                }) {
                    Text(viewModel.callButtonText)
                        .padding()
                        .background(viewModel.isConnected ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.bottom, 50)
            }
        }
    }
}

struct VideoView: UIViewRepresentable {
    let rtcVideoView: RTCMTLVideoView
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        return rtcVideoView
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // Обновление не требуется
    }
}

struct CallView_Previews: PreviewProvider {
    static var previews: some View {
        CallView()
    }
}
