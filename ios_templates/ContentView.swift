//
//  ContentView.swift
//  Example iOS App View for Ubuntu API Connection
//
//  Demonstrates authentication, API calls, and WebSocket usage
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var apiManager = APIManager.shared
    @StateObject private var wsManager = WebSocketManager.shared

    @State private var email = "test@example.com"
    @State private var password = "test123"
    @State private var showingLogin = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var serverHealth: HealthResponse?
    @State private var fetchedData: DataResponse?
    @State private var commandText = ""
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            if apiManager.isAuthenticated {
                authenticatedView
            } else {
                loginView
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Login View

    var loginView: some View {
        VStack(spacing: 20) {
            Text("Ubuntu API Login")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 10) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)

                Text("Password")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)

            Button(action: performLogin) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text("Login")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(isLoading)

            Button("Check Server Health") {
                checkServerHealth()
            }
            .padding()

            if let health = serverHealth {
                VStack(alignment: .leading) {
                    Text("Server Status: \(health.status)")
                        .foregroundColor(.green)
                    Text("Version: \(health.version)")
                    Text("Uptime: \(Int(health.uptime))s")
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Authenticated View

    var authenticatedView: some View {
        TabView {
            // API Tab
            apiTab
                .tabItem {
                    Label("API", systemImage: "server.rack")
                }

            // WebSocket Tab
            webSocketTab
                .tabItem {
                    Label("WebSocket", systemImage: "antenna.radiowaves.left.and.right")
                }

            // Profile Tab
            profileTab
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }

    var apiTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("API Operations")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Fetch Data
                Button("Fetch Protected Data") {
                    fetchData()
                }
                .buttonStyle(PrimaryButtonStyle())

                if let data = fetchedData {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("User ID: \(data.userId)")
                        Text("Timestamp: \(data.timestamp)")
                        Text("Items: \(data.data.items.joined(separator: ", "))")
                        Text("Count: \(data.data.count)")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }

                // Send Command
                VStack(alignment: .leading, spacing: 10) {
                    Text("Send Command")
                        .font(.headline)

                    HStack {
                        TextField("Enter command", text: $commandText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button("Send") {
                            sendCommand()
                        }
                        .disabled(commandText.isEmpty)
                    }
                }
                .padding()

                Spacer()
            }
            .padding()
        }
    }

    var webSocketTab: some View {
        VStack(spacing: 20) {
            Text("WebSocket Status")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Connection Status
            HStack {
                Circle()
                    .fill(wsManager.isConnected ? Color.green : Color.red)
                    .frame(width: 15, height: 15)
                Text(wsManager.connectionStatus)
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            // Connect/Disconnect Button
            Button(wsManager.isConnected ? "Disconnect" : "Connect") {
                if wsManager.isConnected {
                    wsManager.disconnect()
                } else {
                    wsManager.connect()
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            // Request Status Button
            Button("Request Server Status") {
                wsManager.requestStatus()
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!wsManager.isConnected)

            // Last Message
            if let lastMessage = wsManager.lastMessage {
                VStack(alignment: .leading) {
                    Text("Last Message:")
                        .font(.headline)
                    Text(lastMessage)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(5)
                }
                .padding()
            }

            Spacer()
        }
        .padding()
    }

    var profileTab: some View {
        VStack(spacing: 20) {
            Text("Profile")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let user = apiManager.currentUser {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Name:")
                            .fontWeight(.semibold)
                        Text(user.name)
                    }
                    HStack {
                        Text("Email:")
                            .fontWeight(.semibold)
                        Text(user.email)
                    }
                    HStack {
                        Text("ID:")
                            .fontWeight(.semibold)
                        Text(user.id)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }

            Button("Logout") {
                apiManager.logout()
                wsManager.disconnect()
            }
            .buttonStyle(DestructiveButtonStyle())

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    func performLogin() {
        isLoading = true

        Task {
            do {
                let user = try await apiManager.login(email: email, password: password)
                print("Logged in as: \(user.name)")

                // Connect WebSocket after successful login
                DispatchQueue.main.async {
                    wsManager.connect()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }

    func checkServerHealth() {
        Task {
            do {
                let health = try await apiManager.checkHealth()
                await MainActor.run {
                    serverHealth = health
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to reach server. Is the Ubuntu server running?"
                    showingError = true
                }
            }
        }
    }

    func fetchData() {
        Task {
            do {
                let data = try await apiManager.fetchData()
                await MainActor.run {
                    fetchedData = data
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    func sendCommand() {
        guard !commandText.isEmpty else { return }

        Task {
            do {
                let response = try await apiManager.sendCommand(commandText)
                print("Command response: \(response)")
                await MainActor.run {
                    commandText = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}