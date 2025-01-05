//
//  ContentViewModel.swift
//  AiPPSpeechToText
//
//  Created by Daniel Molina on 05/01/25.
//

import Foundation
import AVFoundation

class ContentViewModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    @Published var transcriptionResult: TranscriptionResult?
    private let transcriptionAgent: TranscriptionAgent
    private let textCleaningAgent: TextCleaningAgent
    private var audioRecorder: AVAudioRecorder?
    private var captureSession: AVCaptureSession?
    private var audioInput: AVCaptureDeviceInput?
    private var audioFileOutput: AVCaptureMovieFileOutput?
    private var fileURL: URL?
    private weak var recordingDelegate: AVCaptureFileOutputRecordingDelegate?

    init(transcriptionAgent: TranscriptionAgent, textCleaningAgent: TextCleaningAgent, recordingDelegate: AVCaptureFileOutputRecordingDelegate) {
        self.transcriptionAgent = transcriptionAgent
        self.textCleaningAgent = textCleaningAgent
        self.recordingDelegate = recordingDelegate
        super.init()
        setupAudioCapture()
    }

    func startRecording() {
        guard let captureSession = captureSession, !captureSession.isRunning else {
            print("Capture session is not setup or already running")
            return
        }
        
        fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recording.mov")
        
        if let fileURL = fileURL, let recordingDelegate = recordingDelegate {
            audioFileOutput?.startRecording(to: fileURL, recordingDelegate: recordingDelegate)
            captureSession.startRunning()
        }
    }

    func stopRecording() async {
        guard let captureSession = captureSession, captureSession.isRunning else {
            print("Capture session is not running")
            return
        }
        
        audioFileOutput?.stopRecording()
        captureSession.stopRunning()
        
        guard let fileURL = fileURL else {
            print("Error: No audio URL found")
            return
        }

        do {
            let audioData = try Data(contentsOf: fileURL)
            let transcribedText = try await transcriptionAgent.transcribe(audioData: audioData)
            let cleanedText = try await textCleaningAgent.cleanText(text: transcribedText)
            DispatchQueue.main.async {
                self.transcriptionResult = TranscriptionResult(originalText: transcribedText, cleanedText: cleanedText)
            }
        } catch {
            print("Error processing audio: \(error)")
        }
    }

    private func setupAudioCapture() {
        captureSession = AVCaptureSession()
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("Could not get default audio device")
            return
        }

        do {
            audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if let audioInput = audioInput, captureSession!.canAddInput(audioInput) {
                captureSession!.addInput(audioInput)
            } else {
                print("Could not add audio input to capture session")
                return
            }
            
            audioFileOutput = AVCaptureMovieFileOutput()
            if let audioFileOutput = audioFileOutput, captureSession!.canAddOutput(audioFileOutput) {
                audioFileOutput.movieFragmentInterval = .invalid // For continuous recording
                audioFileOutput.delegate = self
                captureSession!.addOutput(audioFileOutput)
            } else {
                print("Could not add audio output to capture session")
                return
            }
            
        } catch {
            print("Error setting up audio capture: \(error)")
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Handle recording completion if needed
    }
}
