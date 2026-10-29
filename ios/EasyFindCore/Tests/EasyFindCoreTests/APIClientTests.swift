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

  func testFeedbackEncodesAttachmentsAndReturnsServerReceipt() async throws {
    let ident = UUID().uuidString
    let attachment = Data([0, 1, 2, 255])
    StubProtocol.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/feedback")
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer client-token")
      let stream = try XCTUnwrap(request.httpBodyStream)
      stream.open()
      defer { stream.close() }
      var buffer = [UInt8](repeating: 0, count: 1024)
      var body = Data()
      while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        body.append(buffer, count: count)
      }
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
      XCTAssertEqual(json["details"] as? String, "A suggestion")
      let images = try XCTUnwrap(json["attachments"] as? [[String: String]])
      XCTAssertEqual(images, [["image_base64": attachment.base64EncodedString()]])
      return (201, Data("{\"id\":\"\(ident)\"}".utf8))
    }
    let receipt = try await client().submitFeedback(
      category: "建议", details: "A suggestion", contact: "", attachments: [attachment])
    XCTAssertEqual(receipt.id, ident)
  }

  func testFeedbackRejectsInvalidAttachmentsBeforeNetworkRequest() async throws {
    StubProtocol.handler = { _ in
      XCTFail("Invalid attachments must not reach the server")
      return (500, Data())
    }
    for attachments in [
      [Data()], [Data(repeating: 1, count: 512 * 1024 + 1)],
      Array(repeating: Data([1]), count: 11),
    ] {
      do {
        _ = try await client().submitFeedback(
          category: "建议", details: "A suggestion", contact: "", attachments: attachments)
        XCTFail("Must reject invalid attachment")
      } catch { XCTAssertEqual(error as? ServiceError, .invalidResponse) }
    }
  }
}
