//
//  APIManager.swift
//  iOS App Template for Ubuntu API Connection
//
//  Manages all API communications with Ubuntu server via Cloudflare Tunnel
//

import Foundation
import Combine

// MARK: - Configuration

struct APIConfig {
    static let baseURL = "https://api.timrattigan.com"
    static let wsURL = "wss://api.timrattigan.com"
    static let healthURL = "https://health.api.timrattigan.com"

    // Fallback to Vercel if Ubuntu is down
    static let fallbackURL = "https://backup.vercel.app"

    static let timeoutInterval: TimeInterval = 30
    static let maxRetries = 3
}

// MARK: - Error Types

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
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .unauthorized:
            return "Unauthorized - please login"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .tokenExpired:
            return "Session expired - please login again"
        }
    }
}

// MARK: - API Response Models

struct AuthResponse: Codable {
    let message: String
    let token: String
    let user: User
}

struct User: Codable {
    let id: String
    let email: String
    let name: String
}

struct HealthResponse: Codable {
    let status: String
    let timestamp: String
    let uptime: Double
    let service: String
    let version: String
}

struct DataResponse: Codable {
    let message: String
    let userId: String
    let timestamp: String
    let data: DataItems
}

struct DataItems: Codable {
    let items: [String]
    let count: Int
}

struct CommandResponse: Codable {
    let command: String
    let status: String
    let timestamp: String
    let result: String
}

// MARK: - Keychain Helper

class KeychainHelper {
    static let shared = KeychainHelper()
    private let tokenKey = "com.yourapp.apitoken"

    func saveToken(_ token: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - API Manager

class APIManager: ObservableObject {
    static let shared = APIManager()
    private var cancellables = Set<AnyCancellable>()

    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private var baseURL: String {
        // Could implement logic to switch to fallback if primary fails
        return APIConfig.baseURL
    }

    private init() {
        checkAuthentication()
    }

    // MARK: - Authentication

    private func checkAuthentication() {
        isAuthenticated = KeychainHelper.shared.getToken() != nil
    }

    func login(email: String, password: String) async throws -> User {
        let url = URL(string: "\(baseURL)/api/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)

        // Save token to keychain
        KeychainHelper.shared.saveToken(authResponse.token)

        // Update state
        await MainActor.run {
            self.isAuthenticated = true
            self.currentUser = authResponse.user
        }

        return authResponse.user
    }

    func register(email: String, password: String, name: String) async throws -> User {
        let url = URL(string: "\(baseURL)/api/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email, "password": password, "name": name]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 201 else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)

        // Save token to keychain
        KeychainHelper.shared.saveToken(authResponse.token)

        // Update state
        await MainActor.run {
            self.isAuthenticated = true
            self.currentUser = authResponse.user
        }

        return authResponse.user
    }

    func logout() {
        KeychainHelper.shared.deleteToken()
        isAuthenticated = false
        currentUser = nil
    }

    // MARK: - API Requests

    private func authenticatedRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainHelper.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body
        request.timeoutInterval = APIConfig.timeoutInterval

        return request
    }

    func checkHealth() async throws -> HealthResponse {
        let url = URL(string: "\(baseURL)/api/health")!
        let request = URLRequest(url: url)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    func fetchData() async throws -> DataResponse {
        let url = URL(string: "\(baseURL)/api/data")!
        let request = authenticatedRequest(url: url)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.tokenExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(DataResponse.self, from: data)
    }

    func sendCommand(_ command: String) async throws -> CommandResponse {
        let url = URL(string: "\(baseURL)/api/command")!

        let body = try JSONEncoder().encode(["command": command])
        let request = authenticatedRequest(url: url, method: "POST", body: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.tokenExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(CommandResponse.self, from: data)
    }

    // MARK: - Retry Logic

    func withRetry<T>(maxAttempts: Int = APIConfig.maxRetries,
                       delay: TimeInterval = 1.0,
                       operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry on authentication errors
                if case APIError.unauthorized = error {
                    throw error
                }
                if case APIError.tokenExpired = error {
                    throw error
                }

                // Wait before retrying
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(delay * Double(attempt) * 1_000_000_000))
                }
            }
        }

        throw lastError ?? APIError.networkError(URLError(.unknown))
    }
}

// MARK: - Usage Examples

/*
 // Login
 Task {
     do {
         let user = try await APIManager.shared.login(email: "test@example.com", password: "test123")
         print("Logged in as: \(user.name)")
     } catch {
         print("Login failed: \(error)")
     }
 }

 // Fetch data with retry
 Task {
     do {
         let data = try await APIManager.shared.withRetry {
             try await APIManager.shared.fetchData()
         }
         print("Received data: \(data)")
     } catch {
         print("Failed to fetch data: \(error)")
     }
 }

 // Send command
 Task {
     do {
         let result = try await APIManager.shared.sendCommand("test_command")
         print("Command result: \(result.result)")
     } catch {
         print("Command failed: \(error)")
     }
 }
 */