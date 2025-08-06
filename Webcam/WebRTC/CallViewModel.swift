//
//  CallViewModel.swift
//  CallExample
//
//  Created by Maxim Golovlev on 06.08.2025.
//

import Foundation
import Combine
import WebRTC

class CallViewModel: ObservableObject {
    @Published var isConnected = false
    @Published var callButtonText = "Start Call"
    @Published var localVideoView: RTCMTLVideoView?
    @Published var remoteVideoView: RTCMTLVideoView?
    
    private var webRTCManager: WebRTCManager
    private var signalingClient: SignalingClient
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Замените URL на адрес вашего WebSocket сервера
        let websocketURL = URL(string: "ws://192.168.0.104:8080")!
        
        webRTCManager = WebRTCManager()
        signalingClient = SignalingClient(url: websocketURL)
        
        setupBindings()
        webRTCManager.setupLocalStream()
    }
    
    private func setupBindings() {
        // Подписки на WebRTC события
        webRTCManager.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
        
        webRTCManager.$localVideoView
            .receive(on: DispatchQueue.main)
            .assign(to: &$localVideoView)
        
        webRTCManager.$remoteVideoView
            .receive(on: DispatchQueue.main)
            .assign(to: &$remoteVideoView)
        
        // Обработка изменения состояния соединения
        $isConnected
            .map { $0 ? "End Call" : "Start Call" }
            .assign(to: &$callButtonText)
        
        // Настройка обработчиков WebRTC
        webRTCManager.onOfferCreated = { [weak self] offer in
            self?.signalingClient.sendSDP(offer)
        }
        
        webRTCManager.onAnswerCreated = { [weak self] answer in
            self?.signalingClient.sendSDP(answer)
        }
        
        webRTCManager.onIceCandidate = { [weak self] candidate in
            self?.signalingClient.sendCandidate(candidate)
        }
        
        // Настройка обработчиков сигнального клиента
        signalingClient.onReceivedSDP = { [weak self] sdp in
            guard let self = self else { return }
            
            if sdp.type == .offer {
                self.webRTCManager.setRemoteDescription(sdp)
                self.webRTCManager.createAnswer()
            } else if sdp.type == .answer {
                self.webRTCManager.setRemoteDescription(sdp)
            }
        }
        
        signalingClient.onReceivedCandidate = { [weak self] candidate in
            self?.webRTCManager.addIceCandidate(candidate)
        }
    }
    
    func toggleCall() {
        if isConnected {
            endCall()
        } else {
            startCall()
        }
    }
    
    private func startCall() {
        webRTCManager.createOffer()
    }
    
    private func endCall() {
        webRTCManager.hangUp()
    }
}
