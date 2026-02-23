import Foundation
import AuthenticationServices
import CryptoKit

// MARK: - Models

struct OutlookFlaggedEmail: Codable, Identifiable, Sendable {
    let id: String
    let subject: String?
    let from: EmailAddress?
    let bodyPreview: String?
    let receivedDateTime: String?
    let webLink: String?
    let flag: EmailFlag?

    struct EmailAddress: Codable, Sendable {
        let emailAddress: EmailAddressDetail?
    }

    struct EmailAddressDetail: Codable, Sendable {
        let name: String?
        let address: String?
    }

    struct EmailFlag: Codable, Sendable {
        let flagStatus: String?
        let dueDateTime: DateTimeInfo?

        struct DateTimeInfo: Codable, Sendable {
            let dateTime: String?
            let timeZone: String?
        }
    }

    var senderName: String {
        from?.emailAddress?.name ?? from?.emailAddress?.address ?? "Unknown"
    }

    var senderAddress: String {
        from?.emailAddress?.address ?? ""
    }

    var dueDate: Date? {
        guard let dtString = flag?.dueDateTime?.dateTime else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dtString) { return date }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dtString) { return date }
        // Try simple date format
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
        return simple.date(from: dtString)
    }
}

struct GraphResponse<T: Codable & Sendable>: Codable, Sendable where T: Sendable {
    let value: [T]
    // @odata.nextLink for pagination if needed
}

// MARK: - Token Storage

struct OutlookTokens: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-60) // 1 min buffer
    }
}

// MARK: - Service

@MainActor
@Observable
final class OutlookService {
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?
    var flaggedEmails: [OutlookFlaggedEmail] = []

    private let settings = UserSettings.shared
    private var tokens: OutlookTokens?
    private var authSession: ASWebAuthenticationSession?

    // Microsoft identity platform endpoints
    private let authorizeURL = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
    private let tokenURL = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
    private let graphBaseURL = "https://graph.microsoft.com/v1.0"
    private let scopes = "Mail.Read offline_access"
    private let redirectURI = "procrastinaut://outlook-auth"

    init() {
        loadTokens()
    }

    // MARK: - Auth (PKCE)

    func authenticate(presentationAnchor: ASPresentationAnchor) {
        let clientID = settings.outlookClientID
        guard !clientID.isEmpty else {
            errorMessage = "Enter your Azure Client ID in Settings > Outlook first."
            return
        }

        // Generate PKCE
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(string: authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "response_mode", value: "query"),
        ]

        guard let authURL = components.url else {
            errorMessage = "Failed to build auth URL"
            return
        }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "procrastinaut"
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        return // User cancelled
                    }
                    self?.errorMessage = "Auth error: \(error.localizedDescription)"
                    return
                }

                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    self?.errorMessage = "No authorization code received"
                    return
                }

                await self?.exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)
            }
        }

        session.presentationContextProvider = PresentationContextProvider(anchor: presentationAnchor)
        session.prefersEphemeralWebBrowserSession = false
        session.start()
        self.authSession = session
    }

    func signOut() {
        tokens = nil
        isAuthenticated = false
        flaggedEmails = []
        deleteTokens()
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async {
        let clientID = settings.outlookClientID

        let body = [
            "client_id": clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier,
        ].map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")

        await performTokenRequest(body: body)
    }

    private func refreshAccessToken() async -> Bool {
        guard let refreshToken = tokens?.refreshToken else {
            isAuthenticated = false
            return false
        }

        let clientID = settings.outlookClientID
        let body = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": scopes,
        ].map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")

        await performTokenRequest(body: body)
        return isAuthenticated
    }

    private func performTokenRequest(body: String) async {
        guard let url = URL(string: tokenURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                errorMessage = "Token request failed: \(errorBody)"
                isAuthenticated = false
                return
            }

            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            let newTokens = OutlookTokens(
                accessToken: tokenResponse.access_token,
                refreshToken: tokenResponse.refresh_token ?? tokens?.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
            )
            self.tokens = newTokens
            self.isAuthenticated = true
            self.errorMessage = nil
            saveTokens(newTokens)
        } catch {
            errorMessage = "Token request error: \(error.localizedDescription)"
            isAuthenticated = false
        }
    }

    // MARK: - Fetch Flagged Emails

    func fetchFlaggedEmails() async {
        isLoading = true
        defer { isLoading = false }

        guard var currentTokens = tokens else {
            isAuthenticated = false
            errorMessage = "Not authenticated"
            return
        }

        // Refresh if expired
        if currentTokens.isExpired {
            let refreshed = await refreshAccessToken()
            if !refreshed { return }
            guard let refreshedTokens = tokens else { return }
            currentTokens = refreshedTokens
        }

        let endpoint = "\(graphBaseURL)/me/messages?$filter=flag/flagStatus eq 'flagged'&$select=id,subject,from,bodyPreview,receivedDateTime,webLink,flag&$top=50&$orderby=receivedDateTime desc"

        guard let url = URL(string: endpoint) else {
            errorMessage = "Invalid Graph API URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(currentTokens.accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                return
            }

            if httpResponse.statusCode == 401 {
                // Token expired, try refresh
                let refreshed = await refreshAccessToken()
                if refreshed {
                    await fetchFlaggedEmails() // Retry
                }
                return
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? ""
                errorMessage = "Graph API error (\(httpResponse.statusCode)): \(errorBody)"
                return
            }

            let graphResponse = try JSONDecoder().decode(GraphResponse<OutlookFlaggedEmail>.self, from: data)
            self.flaggedEmails = graphResponse.value
            self.errorMessage = nil
        } catch {
            errorMessage = "Fetch error: \(error.localizedDescription)"
        }
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Token Persistence (UserDefaults, not Keychain since sandboxed)

    private func saveTokens(_ tokens: OutlookTokens) {
        if let data = try? JSONEncoder().encode(tokens) {
            UserDefaults.standard.set(data, forKey: "outlookTokens")
        }
    }

    private func loadTokens() {
        if let data = UserDefaults.standard.data(forKey: "outlookTokens"),
           let saved = try? JSONDecoder().decode(OutlookTokens.self, from: data) {
            self.tokens = saved
            self.isAuthenticated = true
        }
    }

    private func deleteTokens() {
        UserDefaults.standard.removeObject(forKey: "outlookTokens")
    }
}

// MARK: - Token Response

private struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let token_type: String?
}

// MARK: - Presentation Context

private final class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {
    let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
