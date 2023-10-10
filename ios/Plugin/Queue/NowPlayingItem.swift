//
//  NowPlayingItem.swift
//  Capacitor
//
//  Created by Олег  Руссу on 10/10/2023.
//

import Foundation



final class NowPlayingItem {
    let track: QueueTrack
    var count: Int = 0
    var timePlayStarted: Double = 0.0

    init(track: QueueTrack) {
        self.track = track
    }
}
