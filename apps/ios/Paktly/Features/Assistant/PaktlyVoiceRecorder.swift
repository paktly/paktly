import AVFoundation
import Combine
import Foundation

@MainActor
final class PaktlyVoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    enum RecorderError: Error { case permissionDenied, unavailable }
    @Published private(set) var isRecording = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var automaticallyCompletedURL: URL?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?
    private var isManualStop = false

    var formattedDuration: String { String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60) }

    func start() async throws {
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard granted else { throw RecorderError.permissionDenied }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("paktly-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self; recorder.prepareToRecord()
        guard recorder.record(forDuration: 60) else { throw RecorderError.unavailable }
        self.recorder = recorder; recordingURL = url; duration = 0; isRecording = true
        automaticallyCompletedURL = nil; isManualStop = false
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateDuration), userInfo: nil, repeats: true)
    }

    func stop() -> URL? { isManualStop = true; recorder?.stop(); finishSession(); return recordingURL }
    func cancel() {
        recorder?.stop()
        if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        recordingURL = nil; finishSession()
    }
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag && !isManualStop { automaticallyCompletedURL = recordingURL }
        finishSession()
    }
    @objc private func updateDuration() { duration = recorder?.currentTime ?? duration }
    private func finishSession() {
        timer?.invalidate(); timer = nil; isRecording = false; recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
