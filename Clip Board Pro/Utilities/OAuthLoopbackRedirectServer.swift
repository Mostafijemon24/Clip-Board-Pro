//
//  OAuthLoopbackRedirectServer.swift
//  Clip Board Pro
//

import Foundation
import Network

/// Listens on 127.0.0.1 so Google OAuth can complete after the user grants access.
final class OAuthLoopbackRedirectServer: @unchecked Sendable {

    enum ServerError: LocalizedError {
        case invalidPort
        case timeout
        case listenerFailed(String)
        case missingCallbackURL
        case oauthDenied(String)

        var errorDescription: String? {
            switch self {
            case .invalidPort: "Invalid OAuth loopback port."
            case .timeout: "Google sign-in timed out. Try again."
            case .listenerFailed(let message): message
            case .missingCallbackURL: "Google did not redirect back to the app."
            case .oauthDenied(let message): message
            }
        }
    }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "OAuthLoopbackRedirectServer", qos: .userInitiated)

    func waitForRedirect(
        port: UInt16,
        expectedPath: String = "/oauth2callback",
        timeoutSeconds: TimeInterval = 300
    ) async throws -> URL {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw ServerError.invalidPort
        }

        return try await withThrowingTaskGroup(of: URL.self) { group in
            group.addTask {
                try await self.acceptRedirect(port: nwPort, expectedPath: expectedPath)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeoutSeconds))
                throw ServerError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func acceptRedirect(port: NWEndpoint.Port, expectedPath: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let resumeOnce: (Result<URL, Error>) -> Void = { [weak self] result in
                guard !resumed else { return }
                resumed = true
                self?.stop()
                continuation.resume(with: result)
            }

            do {
                let listener = try NWListener(using: .tcp, on: port)
                self.listener = listener

                listener.stateUpdateHandler = { state in
                    if case .failed(let error) = state {
                        resumeOnce(.failure(ServerError.listenerFailed(error.localizedDescription)))
                    }
                }

                listener.newConnectionHandler = { connection in
                    connection.start(queue: self.queue)
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, _, _ in
                        guard let data, let request = String(data: data, encoding: .utf8) else {
                            resumeOnce(.failure(ServerError.missingCallbackURL))
                            return
                        }

                        guard let requestLine = request.split(separator: "\r\n").first else {
                            resumeOnce(.failure(ServerError.missingCallbackURL))
                            return
                        }

                        let parts = requestLine.split(separator: " ")
                        guard parts.count >= 2 else {
                            resumeOnce(.failure(ServerError.missingCallbackURL))
                            return
                        }

                        let pathAndQuery = String(parts[1])
                        guard pathAndQuery.hasPrefix(expectedPath) else {
                            self.sendHTTPResponse(on: connection, status: 404, body: "Not found")
                            return
                        }

                        guard let callbackURL = URL(string: "http://127.0.0.1:\(port.rawValue)\(pathAndQuery)") else {
                            resumeOnce(.failure(ServerError.missingCallbackURL))
                            return
                        }

                        if let error = Self.oauthError(from: callbackURL) {
                            self.sendHTTPResponse(
                                on: connection,
                                status: 400,
                                body: "<html><body><h2>Sign-in failed</h2><p>\(error)</p><p>You can close this tab.</p></body></html>"
                            )
                            resumeOnce(.failure(ServerError.oauthDenied(error)))
                            return
                        }

                        self.sendHTTPResponse(
                            on: connection,
                            status: 200,
                            body: """
                            <html><body style="font-family:-apple-system,sans-serif;text-align:center;padding:48px;">
                            <h2>Signed in to Clip Board Pro</h2>
                            <p>You can close this tab and return to the app.</p>
                            </body></html>
                            """
                        )
                        resumeOnce(.success(callbackURL))
                    }
                }

                listener.start(queue: queue)
            } catch {
                resumeOnce(.failure(error))
            }
        }
    }

    private static func oauthError(from url: URL) -> String? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return nil
        }
        if let error = items.first(where: { $0.name == "error" })?.value {
            let description = items.first(where: { $0.name == "error_description" })?.value
            return description ?? error
        }
        return nil
    }

    private func sendHTTPResponse(on connection: NWConnection, status: Int, body: String) {
        let response = """
        HTTP/1.1 \(status) \(status == 200 ? "OK" : "Error")\r
        Content-Type: text/html; charset=utf-8\r
        Connection: close\r
        Content-Length: \(body.utf8.count)\r
        \r
        \(body)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
