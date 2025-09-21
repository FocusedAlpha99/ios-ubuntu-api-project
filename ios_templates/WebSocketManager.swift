//
//  WebSocketManager.swift
//  iOS WebSocket Client for Ubuntu Server
//
//  Manages WebSocket connections via Cloudflare Tunnel
//

import Foundation
import Combine

// MARK: - WebSocket Events

enum WebSocketEvent {
    case connected
    case disconnected
    case message(String)
    case error(Error)
    case statusUpdate([String: Any])
}

// MARK: - WebSocket Manager

class WebSocketManager: NSObject, ObservableObject {
    static let shared = WebSocketManager()

    @Published var isConnected = false
    @Published var lastMessage: String?
    @Published var connectionStatus = "Disconnected"

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private let eventSubject = PassthroughSubject<WebSocketEvent, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var pingTimer: Timer?

    var eventPublisher: AnyPublisher<WebSocketEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    override private init() {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }

    // MARK: - Connection Management

    func connect() {
        guard let token = KeychainHelper.shared.getToken() else {
            print("No auth token available")
            eventSubject.send(.error(APIError.unauthorized))
            return
        }

        disconnect() // Ensure clean state

        guard let url = URL(string: APIConfig.wsURL) else {
            print("Invalid WebSocket URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()

        connectionStatus = "Connecting..."
        receiveMessage()
        startPing()
    }

    func disconnect() {
        stopPing()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        connectionStatus = "Disconnected"
        eventSubject.send(.disconnected)
    }

    // MARK: - Message Handling

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("Received message: \(text)")
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        print("Received data message: \(text)")
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }

                // Continue receiving messages
                self.receiveMessage()

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self.handleError(error)
            }
        }
    }

    private func handleMessage(_ text: String) {
        DispatchQueue.main.async {
            self.lastMessage = text
        }

        // Try to parse as JSON for structured messages
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

            // Handle specific message types
            if let type = json["type"] as? String {
                switch type {
                case "welcome":
                    handleWelcomeMessage(json)
                case "status_update":
                    handleStatusUpdate(json)
                case "command_executed":
                    handleCommandExecuted(json)
                default:
                    eventSubject.send(.message(text))
                }
            } else {
                eventSubject.send(.message(text))
            }
        } else {
            eventSubject.send(.message(text))
        }
    }

    private func handleWelcomeMessage(_ json: [String: Any]) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected"
        }
        eventSubject.send(.connected)
        print("Connected to server: \(json["message"] ?? "")")
    }

    private func handleStatusUpdate(_ json: [String: Any]) {
        eventSubject.send(.statusUpdate(json))
    }

    private func handleCommandExecuted(_ json: [String: Any]) {
        if let command = json["command"] as? String,
           let result = json["result"] as? String {
            print("Command executed: \(command) -> \(result)")
        }
    }

    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Error: \(error.localizedDescription)"
        }
        eventSubject.send(.error(error))

        // Attempt to reconnect after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.webSocketTask == nil {
                print("Attempting to reconnect...")
                self?.connect()
            }
        }
    }

    // MARK: - Sending Messages

    func send(message: String) {
        guard let webSocketTask = webSocketTask else {
            print("WebSocket not connected")
            return
        }

        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    func send(data: Data) {
        guard let webSocketTask = webSocketTask else {
            print("WebSocket not connected")
            return
        }

        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    func sendJSON(_ dictionary: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
              let string = String(data: data, encoding: .utf8) else {
            print("Failed to serialize JSON")
            return
        }

        send(message: string)
    }

    // MARK: - Status Request

    func requestStatus() {
        sendJSON(["type": "request_status"])
    }

    // MARK: - Ping/Pong

    private func startPing() {
        stopPing()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.ping()
        }
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func ping() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("Ping failed: \(error)")
                self?.handleError(error)
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        print("WebSocket connection opened")
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected"
        }
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        print("WebSocket connection closed: \(closeCode)")
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Disconnected"
        }
        eventSubject.send(.disconnected)
    }
}

// MARK: - SwiftUI View Example

/*
import SwiftUI

struct WebSocketView: View {
    @StateObject private var wsManager = WebSocketManager.shared
    @State private var messageToSend = ""
    @State private var messages: [String] = []

    var body: some View {
        VStack {
            // Connection Status
            HStack {
                Circle()
                    .fill(wsManager.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(wsManager.connectionStatus)
                Spacer()
                Button(wsManager.isConnected ? "Disconnect" : "Connect") {
                    if wsManager.isConnected {
                        wsManager.disconnect()
                    } else {
                        wsManager.connect()
                    }
                }
            }
            .padding()

            // Messages
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(messages, id: \.self) { message in
                        Text(message)
                            .padding(5)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Send Message
            HStack {
                TextField("Enter message", text: $messageToSend)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Send") {
                    wsManager.send(message: messageToSend)
                    messages.append("Sent: \(messageToSend)")
                    messageToSend = ""
                }
                .disabled(!wsManager.isConnected)
            }
            .padding()
        }
        .onAppear {
            // Subscribe to WebSocket events
            wsManager.eventPublisher
                .sink { event in
                    switch event {
                    case .message(let text):
                        messages.append("Received: \(text)")
                    case .connected:
                        messages.append("System: Connected to server")
                    case .disconnected:
                        messages.append("System: Disconnected from server")
                    case .error(let error):
                        messages.append("Error: \(error.localizedDescription)")
                    case .statusUpdate(let status):
                        messages.append("Status: \(status)")
                    }
                }
                .store(in: &cancellables)
        }
    }

    @State private var cancellables = Set<AnyCancellable>()
}
*/