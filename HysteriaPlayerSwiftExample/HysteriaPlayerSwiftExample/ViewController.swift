//
//  ViewController.swift
//  HysteriaPlayerSwiftExample
//
//  Created by Stan on 8/17/15.
//  Copyright © 2015 saiday. All rights reserved.
//

import UIKit

class ViewController: UIViewController, HysteriaPlayerDelegate, HysteriaPlayerDataSource {
    private let items = [
        "http://a929.phobos.apple.com/us/r1000/143/Music3/v4/2c/4e/69/2c4e69d7-bd0f-8c76-30ca-75f6a2f51ef5/mzaf_1157339944153759874.plus.aac.p.m4a",
        "http://a1136.phobos.apple.com/us/r1000/042/Music5/v4/85/34/8d/85348d57-5bf9-a4a3-9f54-0c3f1d8bc6af/mzaf_5184604190043403959.plus.aac.p.m4a",
        "http://a345.phobos.apple.com/us/r1000/046/Music5/v4/52/53/4b/52534b36-620e-d7f3-c9a8-2f9661652ff5/mzaf_2360247732780989514.plus.aac.p.m4a"
    ]
    
    lazy var hysteriaPlayer = HysteriaPlayer.sharedInstance()

    override func viewDidLoad() {
        super.viewDidLoad()
        
//        This is a very simple project demonstrate how to use
//        HysteriaPlayer in Swift, detailed instructions about
//        HysteriaPlayer are included in another objc example project.

        initHysteriaPlayer()
        hysteriaPlayer.fetchAndPlayPlayerItem(0)
    }

    func initHysteriaPlayer() {
        hysteriaPlayer.delegate = self
        hysteriaPlayer.datasource = self
    }
    
    func numberOfItems(in hysteriaPlayer: HysteriaPlayer) -> Int {
        return items.count
    }
    
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, urlForItemAt index: Int, preBuffer: Bool) -> URL {
        return URL(string: items[index])!
    }
    
    func hysteriaPlayer(_ hysteriaPlayer: HysteriaPlayer, didReadyToPlayWithIdentifier identifier: HysteriaPlayerReadyToPlay) {
        switch identifier {
        case .currentItem:
            hysteriaPlayer.play()
        default:
            break
        }
    }
}

