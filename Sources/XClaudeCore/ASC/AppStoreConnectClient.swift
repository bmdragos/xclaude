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
    public let certificateType: String
    public let expirationDate: String?
  }
}
