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
    func displayPredictionResult(data: String)
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
    }
    
    override func viewDidAppear(_ animated: Bool) {
        startAudioEngine()
        setUpAnalyzer()
        startAnalyze()
    }
    
    private func startAudioEngine() {
        
        inputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        do{
            try audioEngine.start()
        }catch( _){
            print("error in starting the Audio Engin")
        }
    }
    
    private func setUpAnalyzer() {
        
        //分析するものはマイクの音声(ストリーミング)
        analyzer = SNAudioStreamAnalyzer(format: inputFormat)
        
        do {
            let request = try SNClassifySoundRequest(mlModel: soundClassifier.model)
            try analyzer.add(request, withObserver: resultsObserver)
        } catch {
            print("Unable to prepare request: \(error.localizedDescription)")
            return
        }

    }
    
    private func startAnalyze() {
        
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 8000, format: inputFormat) { buffer, time in
            self.analysisQueue.async {
                self.analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
        }
    }
}


extension ViewController: ClassifierDelegate {
    func displayPredictionResult(data: String) {
        DispatchQueue.main.async {
            self.predictLabel.text = data
        }
    }
    
    func displayPredictionResult(identifier: String, confidence: Double) {
        DispatchQueue.main.async {
            self.predictLabel.text = ("Recognition: \(identifier)\nConfidence \(confidence)")
        }
    }
}




class ResultsObserver: NSObject, SNResultsObserving {
    var delegate: ClassifierDelegate?
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let classifications = result.classifications
        var textResult = ""
        
        for i in 0...classifications.count-1 {
            let classification = classifications[i]
            let identifier = classification.identifier
            let confidence = classification.confidence*100
            textResult += "\(identifier) \(confidence)\n"
            
        }
        
        delegate?.displayPredictionResult(data: textResult)
      
    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("The the analysis failed: \(error.localizedDescription)")
    }
    
    func requestDidComplete(_ request: SNRequest) {
        print("The request completed successfully!")
    }
    
}
