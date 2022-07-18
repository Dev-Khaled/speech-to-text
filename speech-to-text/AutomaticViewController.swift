//
//  AutomaticViewController.swift
//  speech-to-text
//
//  Created by Khaled on 18/07/2022.
//

import UIKit
import Speech
import AVKit

class AutomaticViewController: UIViewController {


    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var errorLabel: UILabel!


    
    
    // MARK: - Vars
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var startSending = false {
        didSet {
            if startSending {
                self.activityIndicator.startAnimating()
                self.activityIndicator.isHidden = false
            } else {
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
            }
        }
    }
    private var startWord = "Love"


    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.activityIndicator.isHidden = true
        self.setupSpeech()
    }
    

    // MARK: - Private

    private func setupSpeech() {
        self.speechRecognizer?.delegate = self

        SFSpeechRecognizer.requestAuthorization { (authStatus) in


            switch authStatus {
            case .authorized:
                OperationQueue.main.addOperation() {
                    self.startRecording()
                }
            case .denied:
                print("User denied access to speech recognition")

            case .restricted:
                print("Speech recognition restricted on this device")

            case .notDetermined:
                print("Speech recognition not yet authorized")
            @unknown default:
                print("Speech recognition state @unknown default")
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
            var shouldStartSending = false

            if let result = result {
                
                // Printing
                let transcription = result.bestTranscription.formattedString
                print("transcription", transcription)
                
                let transcriptionSegments = result.bestTranscription.segments
                //print("transcriptionSegments", transcriptionSegments)
                for segment in transcriptionSegments {
                    let string = segment.substring
                    print(string)
                }

                // Start sending
                if self.startSending {
                    self.resultLabel.text = transcription
                    
                } else if transcription.localizedCaseInsensitiveContains(self.startWord) {
                    shouldStartSending = true
                    self.stopRecording()
                
                } else {
                    self.resultLabel.text = "Looking for key: \(self.startWord)"
                }
                
                isFinal = result.isFinal
            }

            if error != nil || isFinal {

                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                if shouldStartSending {
                    self.startSending = true
                    OperationQueue.main.addOperation {
                        self.startRecording()
                    }
                    
                } else {
                    self.errorLabel.text = "Finished listening"
                    self.startSending = false
                }
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

        self.errorLabel.text = "Say something, I'm listening!"
    }


}


// MARK: - SFSpeechRecognizerDelegate Methods

extension AutomaticViewController: SFSpeechRecognizerDelegate {

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            errorLabel.text = "Listening..."
        } else {
            errorLabel.text = "ERROR! Speech Recognizer not available."
        }
    }
}
