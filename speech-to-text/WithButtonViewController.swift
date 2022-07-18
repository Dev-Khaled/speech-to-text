//
//  WithButtonViewController.swift
//  speech-to-text
//
//  Created by Khaled on 18/07/2022.
//

import UIKit
import Speech
import AVKit

class WithButtonViewController: UIViewController {

    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var resultLabel: UILabel!

    
    // MARK: - Vars
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()


    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupSpeech()
    }
    

    // MARK: - Actions

    @IBAction func startSpeechToTextAction(_ sender: UIButton) {

        if audioEngine.isRunning {
            stopRecording()
            self.startButton.isEnabled = false
            self.startButton.setTitle("Start Recording", for: .normal)
            
        } else {
            self.startRecording()
            self.startButton.setTitle("Stop Recording", for: .normal)
        }
    }


    // MARK: - Private

    private func setupSpeech() {

        self.startButton.isEnabled = false
        self.speechRecognizer?.delegate = self

        SFSpeechRecognizer.requestAuthorization { (authStatus) in

            var isButtonEnabled = false

            switch authStatus {
            case .authorized:
                isButtonEnabled = true

            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")

            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")

            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            @unknown default:
                isButtonEnabled = false
                print("Speech recognition state @unknown default")
            }

            OperationQueue.main.addOperation() {
                self.startButton.isEnabled = isButtonEnabled
            }
        }
    }

    //------------------------------------------------------------------------------

    private func stopRecording() {
        self.audioEngine.stop()
        self.recognitionRequest?.endAudio()
    }
    
    private func startRecording() {

        // Clear all previous session data and cancel task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Create instance of audio session to record voice
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                AVAudioSession.Category.record,
                mode: AVAudioSession.Mode.measurement,
                options: AVAudioSession.CategoryOptions.defaultToSpeaker
            )
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession activation issue.")
        }

        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode

        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }

        recognitionRequest.shouldReportPartialResults = true

        self.recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in

            var isFinal = false

            if result != nil {
                self.resultLabel.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
            }

            if error != nil || isFinal {

                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.startButton.isEnabled = true
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            self.recognitionRequest?.append(buffer)
        }

        self.audioEngine.prepare()

        do {
            try self.audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }

        self.resultLabel.text = "Say something, I'm listening!"
    }


}


// MARK: - SFSpeechRecognizerDelegate Methods

extension WithButtonViewController: SFSpeechRecognizerDelegate {

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            self.startButton.isEnabled = true
        } else {
            self.startButton.isEnabled = false
        }
    }
}

