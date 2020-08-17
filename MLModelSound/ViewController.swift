//
//  ViewController.swift
//  MLModelSound
//
//  Created by TanakaHirokazu on 2020/08/02.
//  Copyright © 2020 TanakaHirokazu. All rights reserved.
//

import UIKit
import AVKit
import SoundAnalysis

protocol ClassifierDelegate {
    func displayPredictionResult(identifier: String, confidence: Double)
}

class ViewController: UIViewController {

    private let audioEngine = AVAudioEngine()
    private var soundClassifier = MySoundClassifier()
    
    var inputFormat: AVAudioFormat!
    var analyzer: SNAudioStreamAnalyzer!
    var resultsObserver = ResultsObserver()
    let analysisQueue = DispatchQueue(label: "com.tanakahirokazu.AnalysisQueue")
    
    @IBOutlet weak var predictLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        resultsObserver.delegate = self
        inputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        //分析するものはマイクの音声(ストリーミング)
        analyzer = SNAudioStreamAnalyzer(format: inputFormat)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        startAudioEngine()
        
    }
    
     private func startAudioEngine() {
            do {
                let request = try SNClassifySoundRequest(mlModel: soundClassifier.model)
                try analyzer.add(request, withObserver: resultsObserver)
            } catch {
                print("Unable to prepare request: \(error.localizedDescription)")
                return
            }
           
            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 8000, format: inputFormat) { buffer, time in
                    self.analysisQueue.async {
                        self.analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
                    }
            }
            
            do{
            try audioEngine.start()
            }catch( _){
                print("error in starting the Audio Engin")
            }
        }
}


extension ViewController: ClassifierDelegate {
    func displayPredictionResult(identifier: String, confidence: Double) {
        DispatchQueue.main.async {
            self.predictLabel.text = ("Recognition: \(identifier)\nConfidence \(confidence)")
        }
    }
}




class ResultsObserver: NSObject, SNResultsObserving {
    var delegate: ClassifierDelegate?
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
            let classification = result.classifications.first else { return }


        let confidence = classification.confidence*100

        if confidence > 60 {
            delegate?.displayPredictionResult(identifier: classification.identifier, confidence: confidence)
        }
    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
           print("The the analysis failed: \(error.localizedDescription)")
       }
       
       func requestDidComplete(_ request: SNRequest) {
           print("The request completed successfully!")
       }
    
}
