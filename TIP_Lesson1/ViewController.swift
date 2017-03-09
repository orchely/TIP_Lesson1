//
//  ViewController.swift
//  TIP_Lesson1
//
//  Created by Kazuki Ohara on 2017/03/10.
//  Copyright © 2017年 Kazuki Ohara. All rights reserved.
//

import UIKit
import TwitterImagePipeline

class ViewController: UIViewController, TIPImageFetchDelegate {

    @IBOutlet weak var imageView: UIImageView!

    var pipeline = TIPImagePipeline(identifier: "TIP_Lesson1")!

    override func viewDidLoad() {
        super.viewDidLoad()

        TIPGlobalConfiguration.sharedInstance().logger = Logger()

        let url = URL(string: "https://upload.wikimedia.org/wikipedia/en/5/55/Bsd_daemon.jpg")!
        let request = ImageRequest(imageURL: url)
        let operation = pipeline.operation(with: request, context: nil, delegate: self)
        pipeline.fetchImage(with: operation)
    }

    func tip_imageFetchOperation(_ op: TIPImageFetchOperation, didLoadFinalImage finalResult: TIPImageFetchResult) {
        imageView.image = finalResult.imageContainer.image
    }

}

class ImageRequest: NSObject, TIPImageFetchRequest {

    public var imageURL: URL

    init(imageURL: URL) {
        self.imageURL = imageURL
    }

}

class Logger: NSObject, TIPLogger {

    func tip_log(with level: TIPLogLevel, file: String, function: String, line: Int32, message: String) {
        let map: [TIPLogLevel: String] = [
            .emergency:     "EMG",
            .alert:         "ALT",
            .critical:      "CRT",
            .error:         "ERR",
            .warning:       "WRN",
            .notice:        "NTC",
            .information:   "INT",
            .debug:         "DBG"
        ]
        print("[\(map[level]!)] \(message)")
    }

}
