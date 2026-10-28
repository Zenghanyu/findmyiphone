import XCTest

@testable import EasyFindCore

private final class StubProtocol: URLProtocol {
  static var handler: ((URLRequest) throws -> (Int, Data))?
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      let (code, data) = try Self.handler!(request)
      let response = HTTPURLResponse(
        url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch { client?.urlProtocol(self, didFailWithError: error) }
  }
  override func stopLoading() {}
}

final class APIClientTests: XCTestCase {
  func client() throws -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubProtocol.self]
    return try APIClient(
      baseURL: URL(string: "https://example.com")!, token: "client-token",
      session: URLSession(configuration: configuration))
  }
  override func tearDown() { StubProtocol.handler = nil }

  func testCreationUsesAuthenticationAndIdempotency() async throws {
    let key = UUID()
    let ident = UUID().uuidString
    StubProtocol.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/artwork-jobs")
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer client-token")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), key.uuidString)
      return (202, Data("{\"id\":\"\(ident)\",\"status\":\"pending\",\"error\":null}".utf8))
    }
    let job = try await client().createArtwork(prompt: "mountains", idempotencyKey: key)
    XCTAssertEqual(job.id, ident)
    XCTAssertEqual(job.status, .pending)
  }
  func testServerErrorsRemainErrors() async throws {
    StubProtocol.handler = { _ in (401, Data("{\"detail\":\"访问令牌无效。\"}".utf8)) }
    do {
      _ = try await client().artworkJob(id: UUID().uuidString)
      XCTFail("Must reject 401")
    } catch { XCTAssertEqual(error as? ServiceError, .server(401, "访问令牌无效。")) }
  }
  func testInvalidJSONAndIdentifiersAreRejected() async throws {
    StubProtocol.handler = { _ in (200, Data("invalid".utf8)) }
    for id in [UUID().uuidString, "../../etc/passwd"] {
      do {
        _ = try await client().artworkJob(id: id)
        XCTFail("Must reject invalid response/path")
      } catch { XCTAssertEqual(error as? ServiceError, .invalidResponse) }
    }
  }
}
