import Foundation
import Speech
import AVFoundation

@MainActor
@Observable
final class SpeechRecognitionService {
    var isRecording: Bool = false
    var transcribedText: String = ""
    var isAvailable: Bool = false
    var error: String?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: .current)
        isAvailable = speechRecognizer?.isAvailable ?? false
    }

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        // Request speech recognition authorization
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            error = "Speech recognition permission denied. Enable it in System Settings → Privacy & Security."
            return false
        }

        // Request microphone access
        let micGranted: Bool
        if #available(macOS 14.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = false
        }

        guard micGranted else {
            error = "Microphone access denied. Enable it in System Settings → Privacy & Security."
            return false
        }

        return true
    }

    // MARK: - Recording

    func startRecording() throws {
        // Cancel any existing task
        stopRecording()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            error = "Speech recognition is not available on this device."
            return
        }

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 else {
            error = "No audio input available."
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        transcribedText = ""
        isRecording = true
        error = nil

        // Start recognition — capture self weakly to avoid retain cycles
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, recognitionError in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                if let recognitionError {
                    // Don't treat cancellation as an error
                    let nsError = recognitionError as NSError
                    if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 {
                        self.error = recognitionError.localizedDescription
                    }
                    self.cleanupRecording()
                }

                if result?.isFinal == true {
                    self.cleanupRecording()
                }
            }
        }
    }

    func stopRecording() {
        recognitionRequest?.endAudio()
        cleanupRecording()
    }

    private func cleanupRecording() {
        if let inputNode = audioEngine?.inputNode {
            inputNode.removeTap(onBus: 0)
        }
        audioEngine?.stop()
        audioEngine = nil

        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false
    }
}
