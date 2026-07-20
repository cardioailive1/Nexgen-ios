import Foundation

/// Errors surfaced by the networking layer, mapped to user-friendly messages.
enum NetworkError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(status: Int, message: String?)
    case decoding
    case transport(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "The request address was invalid."
        case .invalidResponse:   return "The server returned an unexpected response."
        case .unauthorized:      return "Your session has expired. Please sign in again."
        case .server(_, let m):  return m ?? "The server ran into a problem."
        case .decoding:          return "We couldn't read the server response."
        case .transport(let m):  return m
        case .unknown:           return "Something went wrong. Please try again."
        }
    }
}
