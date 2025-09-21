# iOS Integration Guide

## Overview

This guide covers the complete integration of the Ubuntu API backend with your iOS application using Swift and SwiftUI.

## Installation

### 1. Copy Required Files

Copy these files from `ios_templates/` to your Xcode project:

```
ios_templates/
├── APIManager.swift       # Core API client
├── WebSocketManager.swift # WebSocket handler
└── ContentView.swift      # Example usage
```

### 2. Update Configuration

In `APIManager.swift`, update the base URL:

```swift
struct APIConfig {
    static let baseURL = "https://api.yourdomain.com"  // Your domain
    static let wsURL = "wss://api.yourdomain.com"
    static let fallbackURL = "https://backup.vercel.app"  // Optional
}
```

### 3. Add to Info.plist

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

## Architecture

### Singleton Pattern

Both `APIManager` and `WebSocketManager` use the singleton pattern:

```swift
let apiManager = APIManager.shared
let wsManager = WebSocketManager.shared
```

### Async/Await

All API calls use modern Swift concurrency:

```swift
Task {
    do {
        let user = try await apiManager.login(email: email, password: password)
        print("Logged in: \(user.name)")
    } catch {
        print("Error: \(error)")
    }
}
```

## Authentication

### Login Flow

```swift
import SwiftUI

struct LoginView: View {
    @StateObject private var apiManager = APIManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button(action: login) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Login")
                }
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }

    func login() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let user = try await apiManager.login(
                    email: email,
                    password: password
                )
                // Navigate to main app
                print("Welcome \(user.name)!")
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
```

### Registration Flow

```swift
func register(email: String, password: String, name: String) async {
    do {
        let user = try await apiManager.register(
            email: email,
            password: password,
            name: name
        )
        print("Registered: \(user.name)")
    } catch APIError.serverError(409) {
        print("User already exists")
    } catch {
        print("Registration failed: \(error)")
    }
}
```

### Token Management

Tokens are automatically stored in Keychain:

```swift
// Token is saved automatically on login/register
KeychainHelper.shared.saveToken(token)

// Check if authenticated
if apiManager.isAuthenticated {
    // User is logged in
}

// Logout
apiManager.logout()
```

## Making API Calls

### Basic Request

```swift
Task {
    do {
        let data = try await apiManager.fetchData()
        print("Received: \(data.items)")
    } catch APIError.tokenExpired {
        // Handle token expiration
        // Could refresh token or show login
    } catch {
        print("Error: \(error)")
    }
}
```

### With Retry Logic

```swift
Task {
    do {
        let data = try await apiManager.withRetry(maxAttempts: 3) {
            try await apiManager.fetchData()
        }
        print("Success after retries: \(data)")
    } catch {
        print("Failed after retries: \(error)")
    }
}
```

### Sending Commands

```swift
func sendCommand(_ command: String) async {
    do {
        let response = try await apiManager.sendCommand(command)
        print("Command result: \(response.result)")
    } catch {
        print("Command failed: \(error)")
    }
}
```

## WebSocket Integration

### Connection Management

```swift
import SwiftUI
import Combine

struct ChatView: View {
    @StateObject private var wsManager = WebSocketManager.shared
    @State private var messages: [String] = []
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack {
            // Connection indicator
            HStack {
                Circle()
                    .fill(wsManager.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(wsManager.connectionStatus)
                Spacer()
            }

            // Messages list
            ScrollView {
                ForEach(messages, id: \.self) { message in
                    Text(message)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            // Connect button
            Button(wsManager.isConnected ? "Disconnect" : "Connect") {
                if wsManager.isConnected {
                    wsManager.disconnect()
                } else {
                    wsManager.connect()
                }
            }
        }
        .padding()
        .onAppear {
            setupWebSocket()
        }
    }

    func setupWebSocket() {
        // Subscribe to WebSocket events
        wsManager.eventPublisher
            .sink { event in
                switch event {
                case .connected:
                    messages.append("✅ Connected to server")

                case .disconnected:
                    messages.append("❌ Disconnected")

                case .message(let text):
                    messages.append("📨 \(text)")

                case .error(let error):
                    messages.append("⚠️ Error: \(error.localizedDescription)")

                case .statusUpdate(let status):
                    messages.append("ℹ️ Status: \(status)")
                }
            }
            .store(in: &cancellables)
    }
}
```

### Sending Messages

```swift
// Send text message
wsManager.send(message: "Hello server!")

// Send JSON data
wsManager.sendJSON([
    "type": "chat",
    "content": "Hello",
    "timestamp": Date().timeIntervalSince1970
])

// Request server status
wsManager.requestStatus()
```

## Error Handling

### Custom Error Types

```swift
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case unauthorized
    case serverError(Int)
    case networkError(Error)
    case tokenExpired

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please login to continue"
        case .tokenExpired:
            return "Session expired, please login again"
        case .serverError(let code):
            return "Server error: \(code)"
        default:
            return "An error occurred"
        }
    }
}
```

### Handling Errors

```swift
Task {
    do {
        let data = try await apiManager.fetchData()
        // Handle success
    } catch APIError.tokenExpired {
        // Show login screen
        showLoginScreen()
    } catch APIError.serverError(429) {
        // Rate limited
        showAlert("Too many requests. Please wait.")
    } catch APIError.networkError {
        // Check internet connection
        showAlert("No internet connection")
    } catch {
        // Generic error
        showAlert(error.localizedDescription)
    }
}
```

## Offline Support

### Check Server Health

```swift
func checkServerStatus() async -> Bool {
    do {
        let health = try await apiManager.checkHealth()
        return health.status == "healthy"
    } catch {
        // Try fallback server
        APIConfig.baseURL = APIConfig.fallbackURL
        return false
    }
}
```

### Implement Retry with Fallback

```swift
func fetchWithFallback() async throws -> DataResponse {
    do {
        // Try primary server
        return try await apiManager.fetchData()
    } catch {
        // Switch to fallback
        let originalURL = APIConfig.baseURL
        APIConfig.baseURL = APIConfig.fallbackURL

        defer {
            // Restore original URL
            APIConfig.baseURL = originalURL
        }

        return try await apiManager.fetchData()
    }
}
```

## Testing

### Unit Tests

```swift
import XCTest
@testable import YourApp

class APIManagerTests: XCTestCase {

    func testLogin() async throws {
        let user = try await APIManager.shared.login(
            email: "test@example.com",
            password: "test123"
        )

        XCTAssertNotNil(user)
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertTrue(APIManager.shared.isAuthenticated)
    }

    func testHealthCheck() async throws {
        let health = try await APIManager.shared.checkHealth()
        XCTAssertEqual(health.status, "healthy")
    }

    func testInvalidLogin() async {
        do {
            _ = try await APIManager.shared.login(
                email: "invalid@example.com",
                password: "wrong"
            )
            XCTFail("Should have thrown error")
        } catch APIError.unauthorized {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
```

### UI Tests

```swift
import XCTest

class LoginUITests: XCTestCase {

    func testLoginFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Enter credentials
        app.textFields["Email"].tap()
        app.textFields["Email"].typeText("test@example.com")

        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("test123")

        // Login
        app.buttons["Login"].tap()

        // Wait for main screen
        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5))
    }
}
```

## Performance Optimization

### 1. Request Caching

```swift
class CachedAPIManager: APIManager {
    private var cache = NSCache<NSString, AnyObject>()

    func fetchDataCached() async throws -> DataResponse {
        let cacheKey = "data" as NSString

        // Check cache
        if let cached = cache.object(forKey: cacheKey) as? DataResponse {
            return cached
        }

        // Fetch fresh
        let data = try await fetchData()
        cache.setObject(data as AnyObject, forKey: cacheKey)
        return data
    }
}
```

### 2. Background Fetch

```swift
func application(_ application: UIApplication,
                 performFetchWithCompletionHandler completionHandler:
                 @escaping (UIBackgroundFetchResult) -> Void) {

    Task {
        do {
            let data = try await APIManager.shared.fetchData()
            // Process data
            completionHandler(.newData)
        } catch {
            completionHandler(.failed)
        }
    }
}
```

### 3. Batch Requests

```swift
func fetchMultipleEndpoints() async throws {
    async let userData = apiManager.fetchData()
    async let health = apiManager.checkHealth()
    async let status = wsManager.requestStatus()

    let (data, healthStatus, wsStatus) = try await (userData, health, status)
    // Process all results together
}
```

## SwiftUI Best Practices

### 1. Environment Object

```swift
// In App file
@main
struct MyApp: App {
    @StateObject private var apiManager = APIManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(apiManager)
        }
    }
}

// In any view
struct SomeView: View {
    @EnvironmentObject var apiManager: APIManager

    var body: some View {
        // Use apiManager
    }
}
```

### 2. Loading States

```swift
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
}

struct DataView: View {
    @State private var loadingState = LoadingState<DataResponse>.idle

    var body: some View {
        Group {
            switch loadingState {
            case .idle:
                Text("Ready to load")
            case .loading:
                ProgressView()
            case .loaded(let data):
                DataList(data: data)
            case .error(let error):
                ErrorView(error: error)
            }
        }
        .task {
            await loadData()
        }
    }

    func loadData() async {
        loadingState = .loading
        do {
            let data = try await APIManager.shared.fetchData()
            loadingState = .loaded(data)
        } catch {
            loadingState = .error(error)
        }
    }
}
```

## Security Considerations

### 1. Certificate Pinning (Optional)

```swift
class PinnedAPIManager: APIManager {
    override func urlSession(_ session: URLSession,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        // Implement certificate pinning
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Verify certificate
        // ...
    }
}
```

### 2. Biometric Authentication

```swift
import LocalAuthentication

func authenticateWithBiometrics() async -> Bool {
    let context = LAContext()
    var error: NSError?

    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        return false
    }

    do {
        try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to access your account"
        )
        return true
    } catch {
        return false
    }
}
```

## Troubleshooting

### Common Issues

**"The certificate for this server is invalid"**
- Ensure you're using HTTPS with valid SSL certificate
- Check Cloudflare Tunnel is running

**"Could not connect to the server"**
- Verify the base URL is correct
- Check server is running: `pm2 status`
- Test with curl: `curl https://api.yourdomain.com/api/health`

**"Invalid token" errors**
- Token may have expired, implement refresh logic
- Check token is being sent in headers

**WebSocket won't connect**
- Ensure user is authenticated first
- Check WebSocket URL uses `wss://` not `ws://`

---

*Last Updated: September 21, 2025*