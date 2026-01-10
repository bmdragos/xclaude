import Foundation
import CryptoKit

/// Client for App Store Connect API
/// https://developer.apple.com/documentation/appstoreconnectapi
public actor AppStoreConnectClient {

  // MARK: - Types

  public struct Credentials: Codable, Sendable {
    public let issuerId: String
    public let keyId: String
    public let privateKeyPath: String

    public init(issuerId: String, keyId: String, privateKeyPath: String) {
      self.issuerId = issuerId
      self.keyId = keyId
      self.privateKeyPath = privateKeyPath
    }
  }

  public enum ASCError: Error, LocalizedError {
    case noCredentials
    case invalidPrivateKey(String)
    case privateKeyNotFound(String)
    case jwtGenerationFailed(String)
    case requestFailed(Int, String)
    case decodingFailed(String)
    case apiError(String, String?) // code, detail

    public var errorDescription: String? {
      switch self {
      case .noCredentials:
        return "App Store Connect credentials not configured. Use asc_configure to set up."
      case .invalidPrivateKey(let reason):
        return "Invalid private key: \(reason)"
      case .privateKeyNotFound(let path):
        return "Private key file not found: \(path)"
      case .jwtGenerationFailed(let reason):
        return "Failed to generate JWT: \(reason)"
      case .requestFailed(let status, let message):
        return "API request failed (\(status)): \(message)"
      case .decodingFailed(let reason):
        return "Failed to decode response: \(reason)"
      case .apiError(let code, let detail):
        return "API error [\(code)]: \(detail ?? "Unknown error")"
      }
    }
  }

  // MARK: - Properties

  private let baseURL = URL(string: "https://api.appstoreconnect.apple.com/v1")!
  private var credentials: Credentials?
  private var cachedToken: String?
  private var tokenExpiry: Date?

  // MARK: - Singleton

  public static let shared = AppStoreConnectClient()

  private init() {}

  // MARK: - Configuration

  /// Configure credentials for API access
  public func configure(credentials: Credentials) throws {
    // Validate that the key file exists
    let keyPath = (credentials.privateKeyPath as NSString).expandingTildeInPath
    guard FileManager.default.fileExists(atPath: keyPath) else {
      throw ASCError.privateKeyNotFound(credentials.privateKeyPath)
    }

    // Validate the key can be loaded
    _ = try loadPrivateKey(from: keyPath)

    self.credentials = credentials
    self.cachedToken = nil
    self.tokenExpiry = nil
  }

  /// Check if credentials are configured
  public func isConfigured() -> Bool {
    return credentials != nil
  }

  /// Get current credentials (for display, key path only)
  public func currentCredentials() -> (issuerId: String, keyId: String, keyPath: String)? {
    guard let creds = credentials else { return nil }
    return (creds.issuerId, creds.keyId, creds.privateKeyPath)
  }

  // MARK: - JWT Generation

  /// Generate a JWT token for API authentication
  private func generateToken() throws -> String {
    guard let creds = credentials else {
      throw ASCError.noCredentials
    }

    let keyPath = (creds.privateKeyPath as NSString).expandingTildeInPath
    let privateKey = try loadPrivateKey(from: keyPath)

    let now = Date()
    let expiry = now.addingTimeInterval(20 * 60) // 20 minutes

    // Header
    let header: [String: Any] = [
      "alg": "ES256",
      "kid": creds.keyId,
      "typ": "JWT"
    ]

    // Payload
    let payload: [String: Any] = [
      "iss": creds.issuerId,
      "iat": Int(now.timeIntervalSince1970),
      "exp": Int(expiry.timeIntervalSince1970),
      "aud": "appstoreconnect-v1"
    ]

    // Encode header and payload
    let headerData = try JSONSerialization.data(withJSONObject: header)
    let payloadData = try JSONSerialization.data(withJSONObject: payload)

    let headerBase64 = headerData.base64URLEncoded()
    let payloadBase64 = payloadData.base64URLEncoded()

    let signingInput = "\(headerBase64).\(payloadBase64)"

    // Sign with ES256
    guard let signingData = signingInput.data(using: .utf8) else {
      throw ASCError.jwtGenerationFailed("Failed to encode signing input")
    }

    let signature = try privateKey.signature(for: signingData)
    let signatureBase64 = signature.rawRepresentation.base64URLEncoded()

    let token = "\(signingInput).\(signatureBase64)"

    // Cache the token
    self.cachedToken = token
    self.tokenExpiry = expiry

    return token
  }

  /// Get a valid token (cached or fresh)
  private func getToken() throws -> String {
    // Return cached token if still valid (with 1 min buffer)
    if let token = cachedToken,
       let expiry = tokenExpiry,
       expiry.timeIntervalSinceNow > 60 {
      return token
    }

    return try generateToken()
  }

  // MARK: - Private Key Loading

  private func loadPrivateKey(from path: String) throws -> P256.Signing.PrivateKey {
    let keyData: Data
    do {
      keyData = try Data(contentsOf: URL(fileURLWithPath: path))
    } catch {
      throw ASCError.privateKeyNotFound(path)
    }

    guard let keyString = String(data: keyData, encoding: .utf8) else {
      throw ASCError.invalidPrivateKey("Could not read key as UTF-8")
    }

    do {
      // Use pemRepresentation which handles PKCS#8 .p8 files directly
      return try P256.Signing.PrivateKey(pemRepresentation: keyString)
    } catch {
      throw ASCError.invalidPrivateKey("Invalid key format: \(error.localizedDescription)")
    }
  }

  // MARK: - API Requests

  /// Make an authenticated GET request
  public func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
    let token = try getToken()

    var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    urlComponents.queryItems = queryItems

    var request = URLRequest(url: urlComponents.url!)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ASCError.requestFailed(0, "Invalid response type")
    }

    if httpResponse.statusCode >= 400 {
      // Try to parse error response
      if let errorResponse = try? JSONDecoder().decode(ASCErrorResponse.self, from: data),
         let firstError = errorResponse.errors.first {
        throw ASCError.apiError(firstError.code, firstError.detail)
      }
      throw ASCError.requestFailed(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
    }

    do {
      let decoder = JSONDecoder()
      return try decoder.decode(T.self, from: data)
    } catch {
      throw ASCError.decodingFailed(error.localizedDescription)
    }
  }

  /// Make an authenticated POST request
  public func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
    let token = try getToken()

    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let encoder = JSONEncoder()
    request.httpBody = try encoder.encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ASCError.requestFailed(0, "Invalid response type")
    }

    if httpResponse.statusCode >= 400 {
      if let errorResponse = try? JSONDecoder().decode(ASCErrorResponse.self, from: data),
         let firstError = errorResponse.errors.first {
        throw ASCError.apiError(firstError.code, firstError.detail)
      }
      throw ASCError.requestFailed(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
    }

    do {
      let decoder = JSONDecoder()
      return try decoder.decode(T.self, from: data)
    } catch {
      throw ASCError.decodingFailed(error.localizedDescription)
    }
  }

  /// Make an authenticated DELETE request
  public func delete(_ path: String) async throws {
    let token = try getToken()

    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "DELETE"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ASCError.requestFailed(0, "Invalid response type")
    }

    if httpResponse.statusCode >= 400 {
      if let errorResponse = try? JSONDecoder().decode(ASCErrorResponse.self, from: data),
         let firstError = errorResponse.errors.first {
        throw ASCError.apiError(firstError.code, firstError.detail)
      }
      throw ASCError.requestFailed(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
    }
  }

  // MARK: - Device Management

  /// List all registered devices
  public func listDevices(platform: String? = nil, status: String? = nil) async throws -> [DeviceData] {
    var queryItems: [URLQueryItem] = [
      URLQueryItem(name: "limit", value: "200")
    ]

    if let platform = platform {
      queryItems.append(URLQueryItem(name: "filter[platform]", value: platform))
    }

    if let status = status {
      queryItems.append(URLQueryItem(name: "filter[status]", value: status))
    }

    let response: DeviceListResponse = try await get("devices", queryItems: queryItems)
    return response.data
  }

  /// Register a new device
  public func registerDevice(name: String, udid: String, platform: String = "IOS") async throws -> DeviceData {
    let request = DeviceCreateRequest(name: name, udid: udid, platform: platform)
    let response: DeviceResponse = try await post("devices", body: request)
    return response.data
  }

  /// Check if a device is already registered
  public func findDevice(udid: String) async throws -> DeviceData? {
    let queryItems = [
      URLQueryItem(name: "filter[udid]", value: udid)
    ]
    let response: DeviceListResponse = try await get("devices", queryItems: queryItems)
    return response.data.first
  }

  // MARK: - Profile Management

  /// List all provisioning profiles
  public func listProfiles(profileType: String? = nil) async throws -> [ProfileData] {
    var queryItems: [URLQueryItem] = [
      URLQueryItem(name: "limit", value: "200")
    ]

    if let profileType = profileType {
      queryItems.append(URLQueryItem(name: "filter[profileType]", value: profileType))
    }

    let response: ProfileListResponse = try await get("profiles", queryItems: queryItems)
    return response.data
  }

  /// Get a specific profile by ID (includes profileContent for download)
  public func getProfile(id: String) async throws -> ProfileData {
    let response: ProfileResponse = try await get("profiles/\(id)")
    return response.data
  }

  /// Find profiles for a bundle identifier
  public func findProfiles(bundleId: String, profileType: String? = nil) async throws -> [ProfileData] {
    // First find the bundle ID record
    guard let bundleIdRecord = try await findBundleId(identifier: bundleId) else {
      return []
    }

    // Then filter profiles
    var queryItems: [URLQueryItem] = [
      URLQueryItem(name: "filter[bundleId]", value: bundleIdRecord.id),
      URLQueryItem(name: "limit", value: "50")
    ]

    if let profileType = profileType {
      queryItems.append(URLQueryItem(name: "filter[profileType]", value: profileType))
    }

    let response: ProfileListResponse = try await get("profiles", queryItems: queryItems)
    return response.data
  }

  /// Create a new provisioning profile
  public func createProfile(
    name: String,
    profileType: String,
    bundleIdId: String,
    certificateIds: [String],
    deviceIds: [String]?
  ) async throws -> ProfileData {
    let request = ProfileCreateRequest(
      name: name,
      profileType: profileType,
      bundleIdId: bundleIdId,
      certificateIds: certificateIds,
      deviceIds: deviceIds
    )
    let response: ProfileResponse = try await post("profiles", body: request)
    return response.data
  }

  /// Delete a provisioning profile
  public func deleteProfile(id: String) async throws {
    try await delete("profiles/\(id)")
  }

  /// Download profile content and save to file
  public func downloadProfile(id: String, to path: String) async throws {
    let profile = try await getProfile(id: id)

    guard let content = profile.attributes.profileContent else {
      throw ASCError.decodingFailed("Profile has no content")
    }

    guard let data = Data(base64Encoded: content) else {
      throw ASCError.decodingFailed("Failed to decode profile content")
    }

    let url = URL(fileURLWithPath: path)
    try data.write(to: url)
  }

  // MARK: - Bundle ID Management

  /// List all bundle IDs
  public func listBundleIds() async throws -> [BundleIdListResponse.BundleIdData] {
    let response: BundleIdListResponse = try await get("bundleIds", queryItems: [
      URLQueryItem(name: "limit", value: "200")
    ])
    return response.data
  }

  /// Find a bundle ID by identifier string
  public func findBundleId(identifier: String) async throws -> BundleIdListResponse.BundleIdData? {
    let response: BundleIdListResponse = try await get("bundleIds", queryItems: [
      URLQueryItem(name: "filter[identifier]", value: identifier)
    ])
    return response.data.first
  }

  /// Create a new bundle ID
  public func createBundleId(identifier: String, name: String, platform: String = "IOS") async throws -> BundleIdListResponse.BundleIdData {
    let request = BundleIdCreateRequest(identifier: identifier, name: name, platform: platform)
    let response: BundleIdResponse = try await post("bundleIds", body: request)
    return response.data
  }

  // MARK: - App Management

  /// List all apps
  public func listApps() async throws -> [AppData] {
    let response: AppDataListResponse = try await get("apps", queryItems: [
      URLQueryItem(name: "limit", value: "200")
    ])
    return response.data
  }

  /// Create a new app
  public func createApp(bundleIdId: String, name: String, sku: String, primaryLocale: String = "en-US") async throws -> AppData {
    let request = AppCreateRequest(bundleIdId: bundleIdId, name: name, sku: sku, primaryLocale: primaryLocale)
    let response: AppDataResponse = try await post("apps", body: request)
    return response.data
  }

  // MARK: - Certificate Management

  /// List all certificates
  public func listCertificates(certificateType: String? = nil) async throws -> [CertificateListResponse.CertificateData] {
    var queryItems: [URLQueryItem] = [
      URLQueryItem(name: "limit", value: "200")
    ]

    if let certType = certificateType {
      queryItems.append(URLQueryItem(name: "filter[certificateType]", value: certType))
    }

    let response: CertificateListResponse = try await get("certificates", queryItems: queryItems)
    return response.data
  }

  /// Find development certificates
  public func findDevelopmentCertificates() async throws -> [CertificateListResponse.CertificateData] {
    // iOS development certificates
    let iosDev = try await listCertificates(certificateType: "IOS_DEVELOPMENT")
    let appleDev = try await listCertificates(certificateType: "DEVELOPMENT")
    return iosDev + appleDev
  }

  /// Find distribution certificates
  public func findDistributionCertificates() async throws -> [CertificateListResponse.CertificateData] {
    let iosDist = try await listCertificates(certificateType: "IOS_DISTRIBUTION")
    let appleDist = try await listCertificates(certificateType: "DISTRIBUTION")
    return iosDist + appleDist
  }

  /// Get a single certificate by ID (includes certificateContent for download)
  public func getCertificate(id: String) async throws -> CertificateListResponse.CertificateData {
    let response: CertificateResponse = try await get("certificates/\(id)")
    return response.data
  }

  /// Create a new certificate from a CSR
  /// - Parameters:
  ///   - csrContent: The CSR in PEM format (including BEGIN/END markers)
  ///   - certificateType: One of: IOS_DEVELOPMENT, IOS_DISTRIBUTION, MAC_APP_DEVELOPMENT,
  ///                      MAC_APP_DISTRIBUTION, MAC_INSTALLER_DISTRIBUTION, DEVELOPER_ID_KEXT,
  ///                      DEVELOPER_ID_APPLICATION, DEVELOPMENT, DISTRIBUTION
  public func createCertificate(csrContent: String, certificateType: String) async throws -> CertificateListResponse.CertificateData {
    let request = CertificateCreateRequest(csrContent: csrContent, certificateType: certificateType)
    let response: CertificateResponse = try await post("certificates", body: request)
    return response.data
  }

  /// Revoke (delete) a certificate
  public func revokeCertificate(id: String) async throws {
    try await delete("certificates/\(id)")
  }

  /// Download certificate content and save to file
  public func downloadCertificate(id: String, to path: String) async throws {
    let cert = try await getCertificate(id: id)

    guard let content = cert.attributes.certificateContent else {
      throw ASCError.decodingFailed("Certificate has no content")
    }

    guard let data = Data(base64Encoded: content) else {
      throw ASCError.decodingFailed("Failed to decode certificate content")
    }

    let url = URL(fileURLWithPath: path)
    try data.write(to: url)
  }

  // MARK: - TestFlight Beta Testers

  /// List beta testers, optionally filtered by app or group
  public func listBetaTesters(appId: String? = nil, groupId: String? = nil) async throws -> [BetaTesterData] {
    var queryItems: [URLQueryItem] = [
      URLQueryItem(name: "limit", value: "200")
    ]

    if let appId = appId {
      queryItems.append(URLQueryItem(name: "filter[apps]", value: appId))
    }

    if let groupId = groupId {
      queryItems.append(URLQueryItem(name: "filter[betaGroups]", value: groupId))
    }

    let response: BetaTesterListResponse = try await get("betaTesters", queryItems: queryItems)
    return response.data
  }

  /// Create a new beta tester and optionally add to groups
  public func createBetaTester(email: String, firstName: String?, lastName: String?, betaGroupIds: [String]?) async throws -> BetaTesterData {
    let request = BetaTesterCreateRequest(
      email: email,
      firstName: firstName,
      lastName: lastName,
      betaGroupIds: betaGroupIds
    )
    let response: BetaTesterResponse = try await post("betaTesters", body: request)
    return response.data
  }

  /// Find a beta tester by email
  public func findBetaTester(email: String) async throws -> BetaTesterData? {
    let response: BetaTesterListResponse = try await get("betaTesters", queryItems: [
      URLQueryItem(name: "filter[email]", value: email)
    ])
    return response.data.first
  }

  /// Delete a beta tester
  public func deleteBetaTester(id: String) async throws {
    try await delete("betaTesters/\(id)")
  }

  // MARK: - TestFlight Beta Groups

  /// List beta groups for an app
  public func listBetaGroups(appId: String? = nil) async throws -> [BetaGroupData] {
    var queryItems: [URLQueryItem] = [
      URLQueryItem(name: "limit", value: "200")
    ]

    if let appId = appId {
      queryItems.append(URLQueryItem(name: "filter[app]", value: appId))
    }

    let response: BetaGroupListResponse = try await get("betaGroups", queryItems: queryItems)
    return response.data
  }

  /// Add testers to a beta group
  public func addTestersToGroup(groupId: String, testerIds: [String]) async throws {
    let request = BetaGroupTesterAddRequest(testerIds: testerIds)
    // This is a relationship endpoint, needs special handling
    var urlRequest = URLRequest(url: baseURL.appendingPathComponent("betaGroups/\(groupId)/relationships/betaTesters"))
    urlRequest.httpMethod = "POST"
    let token = try getToken()
    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(request)

    let (data, response) = try await URLSession.shared.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ASCError.requestFailed(0, "Invalid response type")
    }

    if httpResponse.statusCode >= 400 {
      if let errorResponse = try? JSONDecoder().decode(ASCErrorResponse.self, from: data),
         let firstError = errorResponse.errors.first {
        throw ASCError.apiError(firstError.code, firstError.detail)
      }
      throw ASCError.requestFailed(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
    }
  }

  /// Create a new beta group
  public func createBetaGroup(appId: String, name: String, isInternal: Bool = false, publicLinkEnabled: Bool = false) async throws -> BetaGroupData {
    let request = BetaGroupCreateRequest(appId: appId, name: name, isInternalGroup: isInternal, publicLinkEnabled: publicLinkEnabled)
    let response: BetaGroupResponse = try await post("betaGroups", body: request)
    return response.data
  }

  /// Delete a beta group
  public func deleteBetaGroup(id: String) async throws {
    try await delete("betaGroups/\(id)")
  }

  /// Add a build to a beta group for distribution
  public func addBuildToGroup(groupId: String, buildId: String) async throws {
    let request = BetaGroupBuildAddRequest(buildIds: [buildId])
    // This is a relationship endpoint
    var urlRequest = URLRequest(url: baseURL.appendingPathComponent("betaGroups/\(groupId)/relationships/builds"))
    urlRequest.httpMethod = "POST"
    let token = try getToken()
    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(request)

    let (data, response) = try await URLSession.shared.data(for: urlRequest)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ASCError.requestFailed(0, "Invalid response type")
    }

    if httpResponse.statusCode >= 400 {
      if let errorResponse = try? JSONDecoder().decode(ASCErrorResponse.self, from: data),
         let firstError = errorResponse.errors.first {
        throw ASCError.apiError(firstError.code, firstError.detail)
      }
      throw ASCError.requestFailed(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
    }
  }

  // MARK: - TestFlight Builds

  /// List builds for an app
  public func listBuilds(appId: String, limit: Int = 10) async throws -> [BuildData] {
    let response: BuildListResponse = try await get("builds", queryItems: [
      URLQueryItem(name: "filter[app]", value: appId),
      URLQueryItem(name: "sort", value: "-uploadedDate"),
      URLQueryItem(name: "limit", value: String(limit))
    ])
    return response.data
  }

  /// Get build localizations (What's New text)
  public func getBuildLocalizations(buildId: String) async throws -> [BetaBuildLocalizationData] {
    let response: BetaBuildLocalizationListResponse = try await get("builds/\(buildId)/betaBuildLocalizations")
    return response.data
  }

  /// Set What's New text for a build
  public func setWhatsNew(buildId: String, locale: String = "en-US", whatsNew: String) async throws -> BetaBuildLocalizationData {
    // First check if localization exists
    let existing = try await getBuildLocalizations(buildId: buildId)

    if let existingLoc = existing.first(where: { $0.attributes.locale == locale }) {
      // Update existing
      let request = BetaBuildLocalizationUpdateRequest(id: existingLoc.id, whatsNew: whatsNew)
      let response: BetaBuildLocalizationResponse = try await patch("betaBuildLocalizations/\(existingLoc.id)", body: request)
      return response.data
    } else {
      // Create new
      let request = BetaBuildLocalizationCreateRequest(buildId: buildId, locale: locale, whatsNew: whatsNew)
      let response: BetaBuildLocalizationResponse = try await post("betaBuildLocalizations", body: request)
      return response.data
    }
  }

  /// Make an authenticated PATCH request
  public func patch<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
    let token = try getToken()

    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let encoder = JSONEncoder()
    request.httpBody = try encoder.encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ASCError.requestFailed(0, "Invalid response type")
    }

    if httpResponse.statusCode >= 400 {
      if let errorResponse = try? JSONDecoder().decode(ASCErrorResponse.self, from: data),
         let firstError = errorResponse.errors.first {
        throw ASCError.apiError(firstError.code, firstError.detail)
      }
      throw ASCError.requestFailed(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
    }

    do {
      let decoder = JSONDecoder()
      return try decoder.decode(T.self, from: data)
    } catch {
      throw ASCError.decodingFailed(error.localizedDescription)
    }
  }

  // MARK: - Test Connection

  /// Test the API connection by fetching apps
  public func testConnection() async throws -> String {
    // Fetch apps to verify auth works and show useful info
    let response: AppListResponse = try await get("apps", queryItems: [
      URLQueryItem(name: "limit", value: "10")
    ])

    let appCount = response.data.count
    if appCount == 0 {
      return "Connected (no apps in account)"
    }

    let appNames = response.data.prefix(3).map { $0.attributes.name }
    let suffix = appCount > 3 ? " + \(appCount - 3) more" : ""
    return "Connected (\(appCount) apps: \(appNames.joined(separator: ", "))\(suffix))"
  }
}

// MARK: - Base64 URL Encoding

private extension Data {
  func base64URLEncoded() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

// MARK: - API Response Types

struct ASCErrorResponse: Decodable {
  struct ASCErrorDetail: Decodable {
    let code: String
    let detail: String?
    let status: String
    let title: String
  }
  let errors: [ASCErrorDetail]
}

struct UserListResponse: Decodable {
  struct User: Decodable {
    let id: String
    let type: String
    let attributes: UserAttributes
  }
  struct UserAttributes: Decodable {
    let firstName: String
    let lastName: String
    let username: String
  }
  let data: [User]
}

struct AppListResponse: Decodable {
  struct App: Decodable {
    let id: String
    let type: String
    let attributes: AppAttributes
  }
  struct AppAttributes: Decodable {
    let name: String
    let bundleId: String
  }
  let data: [App]
}

struct DeviceListResponse: Decodable {
  let data: [DeviceData]
}

struct DeviceResponse: Decodable {
  let data: DeviceData
}

public struct DeviceData: Decodable {
  public let id: String
  public let type: String
  public let attributes: DeviceAttributes
}

public struct DeviceAttributes: Decodable {
  public let name: String
  public let platform: String
  public let udid: String
  public let deviceClass: String
  public let status: String
  public let model: String?
  public let addedDate: String?
}

struct DeviceCreateRequest: Encodable {
  let data: DeviceCreateData

  struct DeviceCreateData: Encodable {
    let type: String
    let attributes: DeviceCreateAttributes
  }

  struct DeviceCreateAttributes: Encodable {
    let name: String
    let platform: String
    let udid: String
  }

  init(name: String, udid: String, platform: String = "IOS") {
    self.data = DeviceCreateData(
      type: "devices",
      attributes: DeviceCreateAttributes(
        name: name,
        platform: platform,
        udid: udid
      )
    )
  }
}

// MARK: - Profile Types

struct ProfileListResponse: Decodable {
  let data: [ProfileData]
}

struct ProfileResponse: Decodable {
  let data: ProfileData
}

public struct ProfileData: Decodable {
  public let id: String
  public let type: String
  public let attributes: ProfileAttributes
}

public struct ProfileAttributes: Decodable {
  public let name: String
  public let profileType: String
  public let profileState: String
  public let profileContent: String?
  public let uuid: String?
  public let createdDate: String?
  public let expirationDate: String?
}

struct ProfileCreateRequest: Encodable {
  let data: ProfileCreateData

  struct ProfileCreateData: Encodable {
    let type: String
    let attributes: ProfileCreateAttributes
    let relationships: ProfileRelationships
  }

  struct ProfileCreateAttributes: Encodable {
    let name: String
    let profileType: String
  }

  struct ProfileRelationships: Encodable {
    let bundleId: BundleIdRelationship
    let certificates: CertificatesRelationship
    let devices: DevicesRelationship?
  }

  struct BundleIdRelationship: Encodable {
    let data: BundleIdData
  }

  struct BundleIdData: Encodable {
    let type: String
    let id: String
  }

  struct CertificatesRelationship: Encodable {
    let data: [CertificateData]
  }

  struct CertificateData: Encodable {
    let type: String
    let id: String
  }

  struct DevicesRelationship: Encodable {
    let data: [DeviceRelData]
  }

  struct DeviceRelData: Encodable {
    let type: String
    let id: String
  }

  init(name: String, profileType: String, bundleIdId: String, certificateIds: [String], deviceIds: [String]?) {
    let bundleIdRel = BundleIdRelationship(data: BundleIdData(type: "bundleIds", id: bundleIdId))
    let certsRel = CertificatesRelationship(data: certificateIds.map { CertificateData(type: "certificates", id: $0) })
    let devicesRel = deviceIds.map { ids in
      DevicesRelationship(data: ids.map { DeviceRelData(type: "devices", id: $0) })
    }

    self.data = ProfileCreateData(
      type: "profiles",
      attributes: ProfileCreateAttributes(name: name, profileType: profileType),
      relationships: ProfileRelationships(
        bundleId: bundleIdRel,
        certificates: certsRel,
        devices: devicesRel
      )
    )
  }
}

// MARK: - Bundle ID Types

public struct BundleIdListResponse: Decodable {
  public let data: [BundleIdData]

  public struct BundleIdData: Decodable {
    public let id: String
    public let type: String
    public let attributes: BundleIdAttributes
  }

  public struct BundleIdAttributes: Decodable {
    public let identifier: String
    public let name: String
    public let platform: String?
  }
}

// MARK: - Certificate Types

public struct CertificateListResponse: Decodable {
  public let data: [CertificateData]

  public struct CertificateData: Decodable {
    public let id: String
    public let type: String
    public let attributes: CertificateAttributes
  }

  public struct CertificateAttributes: Decodable {
    public let name: String?
    public let displayName: String?
    public let certificateType: String
    public let expirationDate: String?
    public let serialNumber: String?
    public let certificateContent: String?  // Base64 encoded certificate
  }
}

struct CertificateResponse: Decodable {
  let data: CertificateListResponse.CertificateData
}

struct CertificateCreateRequest: Encodable {
  let data: CertificateCreateData

  struct CertificateCreateData: Encodable {
    let type: String
    let attributes: CertificateCreateAttributes
  }

  struct CertificateCreateAttributes: Encodable {
    let csrContent: String
    let certificateType: String
  }

  init(csrContent: String, certificateType: String) {
    self.data = CertificateCreateData(
      type: "certificates",
      attributes: CertificateCreateAttributes(
        csrContent: csrContent,
        certificateType: certificateType
      )
    )
  }
}

// MARK: - TestFlight Types

public struct BetaTesterListResponse: Decodable {
  public let data: [BetaTesterData]
}

public struct BetaTesterResponse: Decodable {
  public let data: BetaTesterData
}

public struct BetaTesterData: Decodable {
  public let id: String
  public let type: String
  public let attributes: BetaTesterAttributes
}

public struct BetaTesterAttributes: Decodable {
  public let email: String?
  public let firstName: String?
  public let lastName: String?
  public let inviteType: String?
  public let state: String?
}

struct BetaTesterCreateRequest: Encodable {
  let data: BetaTesterCreateData

  struct BetaTesterCreateData: Encodable {
    let type: String
    let attributes: BetaTesterCreateAttributes
    let relationships: BetaTesterRelationships?
  }

  struct BetaTesterCreateAttributes: Encodable {
    let email: String
    let firstName: String?
    let lastName: String?
  }

  struct BetaTesterRelationships: Encodable {
    let betaGroups: BetaGroupsRelationship?
  }

  struct BetaGroupsRelationship: Encodable {
    let data: [BetaGroupRelData]
  }

  struct BetaGroupRelData: Encodable {
    let type: String
    let id: String
  }

  init(email: String, firstName: String?, lastName: String?, betaGroupIds: [String]?) {
    let relationships: BetaTesterRelationships?
    if let groupIds = betaGroupIds, !groupIds.isEmpty {
      relationships = BetaTesterRelationships(
        betaGroups: BetaGroupsRelationship(
          data: groupIds.map { BetaGroupRelData(type: "betaGroups", id: $0) }
        )
      )
    } else {
      relationships = nil
    }

    self.data = BetaTesterCreateData(
      type: "betaTesters",
      attributes: BetaTesterCreateAttributes(
        email: email,
        firstName: firstName,
        lastName: lastName
      ),
      relationships: relationships
    )
  }
}

public struct BetaGroupListResponse: Decodable {
  public let data: [BetaGroupData]
}

public struct BetaGroupData: Decodable {
  public let id: String
  public let type: String
  public let attributes: BetaGroupAttributes
}

public struct BetaGroupAttributes: Decodable {
  public let name: String
  public let isInternalGroup: Bool?
  public let publicLinkEnabled: Bool?
  public let publicLink: String?
}

struct BetaGroupTesterAddRequest: Encodable {
  let data: [BetaTesterRelData]

  struct BetaTesterRelData: Encodable {
    let type: String
    let id: String
  }

  init(testerIds: [String]) {
    self.data = testerIds.map { BetaTesterRelData(type: "betaTesters", id: $0) }
  }
}

public struct BuildListResponse: Decodable {
  public let data: [BuildData]
}

public struct BuildData: Decodable {
  public let id: String
  public let type: String
  public let attributes: BuildAttributes
}

public struct BuildAttributes: Decodable {
  public let version: String?
  public let uploadedDate: String?
  public let expirationDate: String?
  public let expired: Bool?
  public let processingState: String?
  public let usesNonExemptEncryption: Bool?
}

public struct BetaBuildLocalizationListResponse: Decodable {
  public let data: [BetaBuildLocalizationData]
}

public struct BetaBuildLocalizationResponse: Decodable {
  public let data: BetaBuildLocalizationData
}

public struct BetaBuildLocalizationData: Decodable {
  public let id: String
  public let type: String
  public let attributes: BetaBuildLocalizationAttributes
}

public struct BetaBuildLocalizationAttributes: Decodable {
  public let locale: String?
  public let whatsNew: String?
}

struct BetaBuildLocalizationCreateRequest: Encodable {
  let data: BetaBuildLocalizationCreateData

  struct BetaBuildLocalizationCreateData: Encodable {
    let type: String
    let attributes: BetaBuildLocalizationCreateAttributes
    let relationships: BetaBuildLocalizationRelationships
  }

  struct BetaBuildLocalizationCreateAttributes: Encodable {
    let locale: String
    let whatsNew: String?
  }

  struct BetaBuildLocalizationRelationships: Encodable {
    let build: BuildRelationship
  }

  struct BuildRelationship: Encodable {
    let data: BuildRelData
  }

  struct BuildRelData: Encodable {
    let type: String
    let id: String
  }

  init(buildId: String, locale: String, whatsNew: String?) {
    self.data = BetaBuildLocalizationCreateData(
      type: "betaBuildLocalizations",
      attributes: BetaBuildLocalizationCreateAttributes(
        locale: locale,
        whatsNew: whatsNew
      ),
      relationships: BetaBuildLocalizationRelationships(
        build: BuildRelationship(
          data: BuildRelData(type: "builds", id: buildId)
        )
      )
    )
  }
}

struct BetaBuildLocalizationUpdateRequest: Encodable {
  let data: BetaBuildLocalizationUpdateData

  struct BetaBuildLocalizationUpdateData: Encodable {
    let type: String
    let id: String
    let attributes: BetaBuildLocalizationUpdateAttributes
  }

  struct BetaBuildLocalizationUpdateAttributes: Encodable {
    let whatsNew: String?
  }

  init(id: String, whatsNew: String?) {
    self.data = BetaBuildLocalizationUpdateData(
      type: "betaBuildLocalizations",
      id: id,
      attributes: BetaBuildLocalizationUpdateAttributes(whatsNew: whatsNew)
    )
  }
}

// MARK: - Bundle ID Create Types

struct BundleIdResponse: Decodable {
  let data: BundleIdListResponse.BundleIdData
}

struct BundleIdCreateRequest: Encodable {
  let data: BundleIdCreateData

  struct BundleIdCreateData: Encodable {
    let type: String
    let attributes: BundleIdCreateAttributes
  }

  struct BundleIdCreateAttributes: Encodable {
    let identifier: String
    let name: String
    let platform: String
  }

  init(identifier: String, name: String, platform: String) {
    self.data = BundleIdCreateData(
      type: "bundleIds",
      attributes: BundleIdCreateAttributes(
        identifier: identifier,
        name: name,
        platform: platform
      )
    )
  }
}

// MARK: - App Types

public struct AppDataListResponse: Decodable {
  public let data: [AppData]
}

public struct AppDataResponse: Decodable {
  public let data: AppData
}

public struct AppData: Decodable {
  public let id: String
  public let type: String
  public let attributes: AppDataAttributes
}

public struct AppDataAttributes: Decodable {
  public let name: String
  public let bundleId: String
  public let sku: String?
  public let primaryLocale: String?
}

struct AppCreateRequest: Encodable {
  let data: AppCreateData

  struct AppCreateData: Encodable {
    let type: String
    let attributes: AppCreateAttributes
    let relationships: AppRelationships
  }

  struct AppCreateAttributes: Encodable {
    let name: String
    let primaryLocale: String
    let sku: String
  }

  struct AppRelationships: Encodable {
    let bundleId: BundleIdRelationship
  }

  struct BundleIdRelationship: Encodable {
    let data: BundleIdRelData
  }

  struct BundleIdRelData: Encodable {
    let type: String
    let id: String
  }

  init(bundleIdId: String, name: String, sku: String, primaryLocale: String) {
    self.data = AppCreateData(
      type: "apps",
      attributes: AppCreateAttributes(
        name: name,
        primaryLocale: primaryLocale,
        sku: sku
      ),
      relationships: AppRelationships(
        bundleId: BundleIdRelationship(
          data: BundleIdRelData(type: "bundleIds", id: bundleIdId)
        )
      )
    )
  }
}

// MARK: - Beta Group Create Types

struct BetaGroupResponse: Decodable {
  let data: BetaGroupData
}

struct BetaGroupCreateRequest: Encodable {
  let data: BetaGroupCreateData

  struct BetaGroupCreateData: Encodable {
    let type: String
    let attributes: BetaGroupCreateAttributes
    let relationships: BetaGroupRelationships
  }

  struct BetaGroupCreateAttributes: Encodable {
    let name: String
    let isInternalGroup: Bool
    let publicLinkEnabled: Bool
  }

  struct BetaGroupRelationships: Encodable {
    let app: AppRelationship
  }

  struct AppRelationship: Encodable {
    let data: AppRelData
  }

  struct AppRelData: Encodable {
    let type: String
    let id: String
  }

  init(appId: String, name: String, isInternalGroup: Bool, publicLinkEnabled: Bool) {
    self.data = BetaGroupCreateData(
      type: "betaGroups",
      attributes: BetaGroupCreateAttributes(
        name: name,
        isInternalGroup: isInternalGroup,
        publicLinkEnabled: publicLinkEnabled
      ),
      relationships: BetaGroupRelationships(
        app: AppRelationship(
          data: AppRelData(type: "apps", id: appId)
        )
      )
    )
  }
}

struct BetaGroupBuildAddRequest: Encodable {
  let data: [BuildRelData]

  struct BuildRelData: Encodable {
    let type: String
    let id: String
  }

  init(buildIds: [String]) {
    self.data = buildIds.map { BuildRelData(type: "builds", id: $0) }
  }
}
