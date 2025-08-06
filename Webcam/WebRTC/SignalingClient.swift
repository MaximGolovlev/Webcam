//
//  SignalingClient.swift
//  CallExample
//
//  Created by Maxim Golovlev on 06.08.2025.
//

import Foundation
import Starscream
import WebRTC

class SignalingClient: WebSocketDelegate {

    private var socket: WebSocket
    var onReceivedSDP: ((RTCSessionDescription) -> Void)?
    var onReceivedCandidate: ((RTCIceCandidate) -> Void)?
    
    init(url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
    }
    
    func sendSDP(_ sdp: RTCSessionDescription) {
        let type = sdp.type == .offer ? "offer" : "answer"
        let payload: [String: Any] = [
            "type": type,
            "sdp": sdp.sdp
        ]
        sendJSON(payload)
    }
    
    func sendCandidate(_ candidate: RTCIceCandidate) {
        let payload: [String: Any] = [
            "type": "candidate",
            "candidate": candidate.sdp,
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "sdpMid": candidate.sdpMid ?? ""
        ]
        sendJSON(payload)
    }
    
    private func sendJSON(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        socket.write(string: string)
    }
    
    // MARK: - WebSocketDelegate
    
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            print("WebSocket connected: \(headers)")
        case .disconnected(let reason, let code):
            print("WebSocket disconnected: \(reason) with code: \(code)")
        case .text(let string):
            handleMessage(string)
        case .error(let error):
            print("WebSocket error: \(error?.localizedDescription ?? "Unknown error")")
        default:
            break
        }
    }
    
    private func handleMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "offer", "answer":
            if let sdp = json["sdp"] as? String {
                let sdpType: RTCSdpType = type == "offer" ? .offer : .answer
                let sessionDescription = RTCSessionDescription(type: sdpType, sdp: sdp)
                onReceivedSDP?(sessionDescription)
            }
        case "candidate":
            if let candidate = json["candidate"] as? String,
               let sdpMLineIndex = json["sdpMLineIndex"] as? Int32,
               let sdpMid = json["sdpMid"] as? String {
                let iceCandidate = RTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                onReceivedCandidate?(iceCandidate)
            }
        default:
            break
        }
    }
}
