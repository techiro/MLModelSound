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
    func playerPlay()
}

class ViewController: UIViewController {
    
    private let audioEngine = AVAudioEngine()
    private var soundClassifier = MySoundClassifier()
    var audioPlayerNode = AVAudioPlayerNode()
    
    var audioFile:AVAudioFile!
    var inputFormat: AVAudioFormat!
    var analyzer: SNAudioStreamAnalyzer!
    var resultsObserver = ResultsObserver()
    let analysisQueue = DispatchQueue(label: "com.tanakahirokazu.AnalysisQueue")
    
    @IBOutlet weak var predictLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        resultsObserver.delegate = self
        setUpAudioEngine()
        setUpAnalyzer()
        startAnalyze()
        startAudioEngine()
       
    }
    
    override func viewDidAppear(_ animated: Bool) {

    }
    private func setUpAudioEngine() {
        do {
            audioFile = try AVAudioFile(forReading: getAudioFileUrl())
        } catch {
            fatalError("can't add audioFile.")
        }
        //音楽再生のセットアップ
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
        
        //マイクのセットアップ
        inputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        audioEngine.connect(audioEngine.inputNode, to: audioEngine.mainMixerNode, format: inputFormat)
        audioEngine.prepare()
    }
    
    private func startAudioEngine() {
        
        do{
            try audioEngine.start()
            audioPlayerNode.scheduleFile(audioFile!, at: nil, completionCallbackType: .dataPlayedBack) { (callback) in
                print(self.audioPlayerNode.isPlaying)
            }
            
        }catch{
            print(error)
        }
    }
    
    private func getAudioFileUrl() throws-> URL{
        if let url = Bundle.main.url(forResource: "blues.00000", withExtension: "wav") {
           return url
        }else {
            fatalError("not exist URL")
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
    
    @IBAction func didTappedButton(_ sender: Any) {
        audioPlayerNode.play()
    }
    
}


extension ViewController: ClassifierDelegate {
    func playerPlay() {
        self.audioPlayerNode.play()
    }
    
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
    var count = 0
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let classifications = result.classifications
        var textResult = ""
        
        for i in 0...classifications.count-1 {
            let classification = classifications[i]
            let identifier = classification.identifier
            let confidence = floor(classification.confidence*100*100)/100
            if identifier == "blues" && confidence > 90  {
                
                count += 1
                print(count)
                
            }
            if count >= 20 {
                 delegate?.playerPlay()
            }
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
