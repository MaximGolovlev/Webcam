//
//  WebRTCManager.swift
//  CallExample
//
//  Created by Maxim Golovlev on 06.08.2025.
//

import Foundation
import WebRTC

class WebRTCManager: NSObject, ObservableObject {
    private let factory: RTCPeerConnectionFactory
    private var peerConnection: RTCPeerConnection?
    private var localVideoTrack: RTCVideoTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private var videoCapturer: RTCCameraVideoCapturer?
    
    @Published var localVideoView: RTCMTLVideoView?
    @Published var remoteVideoView: RTCMTLVideoView?
    @Published var isConnected = false
    
    // Для сигналинга
    var onOfferCreated: ((RTCSessionDescription) -> Void)?
    var onAnswerCreated: ((RTCSessionDescription) -> Void)?
    var onIceCandidate: ((RTCIceCandidate) -> Void)?
    
    override init() {
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        factory = RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
        super.init()
    }
    
    func setupLocalStream() {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        config.sdpSemantics = .unifiedPlan
        
        peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)
        
        // Создаем локальный поток
        let stream = factory.mediaStream(withStreamId: "localStream")
        
        // Создаем видео трек
        let videoSource = factory.videoSource()
        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        let videoTrack = factory.videoTrack(with: videoSource, trackId: "video0")
        stream.addVideoTrack(videoTrack)
        
        // Создаем аудио трек
        let audioTrack = factory.audioTrack(withTrackId: "audio0")
        stream.addAudioTrack(audioTrack)
        
        // Добавляем треки в peerConnection
        peerConnection?.add(videoTrack, streamIds: [stream.streamId])
        peerConnection?.add(audioTrack, streamIds: [stream.streamId])
        
        // Сохраняем ссылки на треки
        localVideoTrack = videoTrack
        
        // Начинаем захват видео с камеры
        startCapture()
        
        // Создаем видео вью
        DispatchQueue.main.async {
            self.localVideoView = RTCMTLVideoView(frame: .zero)
            self.localVideoView?.videoContentMode = .scaleAspectFill
            self.localVideoTrack?.add(self.localVideoView!)
        }
    }
    
    private func startCapture() {
        guard let capturer = videoCapturer else { return }
        guard let frontCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front }) else { return }
        
        let format = RTCCameraVideoCapturer.supportedFormats(for: frontCamera).last!
        let fps = format.videoSupportedFrameRateRanges.first!.maxFrameRate
        
        capturer.startCapture(with: frontCamera, format: format, fps: Int(fps))
    }
    
    func createOffer() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"],
            optionalConstraints: nil)
        
        peerConnection?.offer(for: constraints) { [weak self] (sdp, error) in
            guard let self = self, let sdp = sdp else { return }
            
            self.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    print("Error setting local description: \(error)")
                }
            }
            
            self.onOfferCreated?(sdp)
        }
    }
    
    func setRemoteDescription(_ sdp: RTCSessionDescription) {
        peerConnection?.setRemoteDescription(sdp) { error in
            if let error = error {
                print("Error setting remote description: \(error)")
            }
        }
    }
    
    func createAnswer() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"],
            optionalConstraints: nil)
        
        peerConnection?.answer(for: constraints) { [weak self] (sdp, error) in
            guard let self = self, let sdp = sdp else { return }
            
            self.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    print("Error setting local description: \(error)")
                }
            }
            
            self.onAnswerCreated?(sdp)
        }
    }
    
    func addIceCandidate(_ candidate: RTCIceCandidate) {
        peerConnection?.add(candidate, completionHandler: { _ in })
    }
    
    func hangUp() {
        peerConnection?.close()
        peerConnection = nil
        videoCapturer?.stopCapture()
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.remoteVideoView = nil
        }
    }
}

extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("Signaling state changed: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("Stream added")
        DispatchQueue.main.async {
            if let track = stream.videoTracks.first {
                self.remoteVideoView = RTCMTLVideoView(frame: .zero)
                self.remoteVideoView?.videoContentMode = .scaleAspectFill
                track.add(self.remoteVideoView!)
                self.isConnected = true
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("Stream removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("Should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("ICE connection state changed: \(newState)")
        if newState == .disconnected || newState == .failed {
            DispatchQueue.main.async {
                self.isConnected = false
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("ICE gathering state changed: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("Generated ICE candidate")
        onIceCandidate?(candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("Removed ICE candidates")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("Data channel opened")
    }
}
