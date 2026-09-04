import Foundation
import Combine

@MainActor
final class PaktlyRealtimeTranscriber: ObservableObject {
    enum RealtimeError: Error { case unavailable, connectionTimedOut, providerRejected, emptyTranscript }

    @Published private(set) var transcript = ""
    @Published private(set) var isConnected = false
    @Published private(set) var failureMessage: String?
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?

    func start(client: APIClient) async throws {
        stop()
        let session = try await client.realtimeTranscriptionSession()
        guard let url = URL(string: "wss://api.openai.com/v1/realtime?intent=transcription") else { throw RealtimeError.unavailable }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.clientSecret)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        request.timeoutInterval = 15
        let task = URLSession.shared.webSocketTask(with: request)
        socket = task; transcript = ""; isConnected = false; failureMessage = nil; task.resume()
        receiveTask = Task { [weak self] in await self?.receiveLoop(task) }
        for _ in 0..<30 {
            if isConnected { return }
            if failureMessage != nil { stop(); throw RealtimeError.providerRejected }
            try await Task.sleep(for: .milliseconds(100))
        }
        stop()
        throw RealtimeError.connectionTimedOut
    }

    nonisolated func append(_ pcm16: Data) {
        Task { @MainActor [weak self] in
            guard let socket = self?.socket else { return }
            let event: [String: Any] = ["type": "input_audio_buffer.append", "audio": pcm16.base64EncodedString()]
            guard let data = try? JSONSerialization.data(withJSONObject: event), let text = String(data: data, encoding: .utf8) else { return }
            do { try await socket.send(.string(text)) }
            catch { self?.failureMessage = "The live transcription connection was interrupted." }
        }
    }

    func finish() async throws -> String {
        if let socket {
            try? await socket.send(.string("{\"type\":\"input_audio_buffer.commit\"}"))
            try? await Task.sleep(for: .milliseconds(900))
        }
        let result = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        stop()
        guard result.count >= 2 else { throw RealtimeError.emptyTranscript }
        return result
    }

    func stop() {
        receiveTask?.cancel(); receiveTask = nil
        socket?.cancel(with: .normalClosure, reason: nil); socket = nil
        isConnected = false
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            guard let message = try? await task.receive() else { return }
            let data: Data
            switch message { case .string(let value): data = Data(value.utf8); case .data(let value): data = value; @unknown default: continue }
            guard let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }
            if type == "session.created" || type == "transcription_session.created" { isConnected = true }
            if type == "error" {
                let detail = (event["error"] as? [String: Any])?["message"] as? String
                failureMessage = detail ?? "OpenAI rejected the live transcription session."
                return
            }
            if type.hasSuffix(".delta"), let delta = event["delta"] as? String { transcript += delta }
            if type.hasSuffix(".completed"), let completed = event["transcript"] as? String, completed.count > transcript.count { transcript = completed }
        }
    }
}
