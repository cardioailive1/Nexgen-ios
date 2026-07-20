import Foundation

/// Thin async wrapper around URLSession that turns `Endpoint`s into decoded models.
protocol APIClientProtocol {
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
    func send(_ endpoint: Endpoint) async throws
}

final class APIClient: APIClientProtocol {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    /// Injected on each request by `AuthenticationManager` when a token exists.
    var authTokenProvider: (() -> String?)?

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        let data = try await perform(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding
        }
    }

    func send(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint)
    }

    // MARK: - Private

    private func perform(_ endpoint: Endpoint) async throws -> Data {
        var endpoint = endpoint
        if let token = authTokenProvider?() {
            endpoint.headers["Authorization"] = "Bearer \(token)"
        }

        let request = try endpoint.urlRequest()
        if AppConfig.networkLoggingEnabled {
            print("→ \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw NetworkError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8)
            throw NetworkError.server(status: http.statusCode, message: message)
        }
    }
}
