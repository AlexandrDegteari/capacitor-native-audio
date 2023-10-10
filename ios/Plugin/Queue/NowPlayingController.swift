//
//  NowPlayingController.swift
//  Capacitor
//
//  Created by Олег  Руссу on 09/10/2023.
//

import Foundation


final class NowPlayingController {

    private let nowPlaying = NowPlaybaleImpl()

    private var playingTracks: [NowPlayingItem] = []
    private let predicate: (NowPlayingItem, QueueTrack) -> Bool = { nowPlayingItem, queueTrack in
        return nowPlayingItem.track.assetId == queueTrack.assetId && nowPlayingItem.track.url == queueTrack.url
    }

    var stopCallback: (() -> ())?

    init() {
        try! nowPlaying.configureRemoteCommands([.stop, .play], disabledCommands: []) { [weak self] command, event in
            guard let self = self else { return .commandFailed }
            playingTracks = []
            stopCallback?()
            stopNowPlaying()
            return .success
        }
    }

    func playerStartedPlaying(track: QueueTrack) {
        var item = playingTracks.first { predicate($0, track) }
        if item == nil {
            item = NowPlayingItem(track: track)
            item!.timePlayStarted = Date().timeIntervalSince1970
            playingTracks.append(item!)
            startNowPlaying(body: getBody())
        }
        item!.count += 1
    }

    func playerStoppedPlaying(track: QueueTrack) {
        guard let item = playingTracks.first(where: { predicate($0, track) }) else { return }
        if item.count == 1 {
            playingTracks.removeAll(where: { predicate($0, track) })
        } else {
            item.count -= 1
        }
        if !playingTracks.isEmpty {
            let body = getBody()
            startNowPlaying(body: body)
            return
        }
        stopNowPlaying()
    }


    private func startNowPlaying(body: String) {
        try? nowPlaying.handleNowPlayableSessionStart()
        let url = URL(string: "localhost:8888")!
        nowPlaying.setNowPlayingMetadata(NowPlayableStaticMetadata(
            assetURL: url,
            mediaType: .audio,
            isLiveStream: true,
            title: body,
            artist: nil,
            artwork: nil,
            albumArtist: nil,
            albumTitle: nil
        ))
    }

    private func stopNowPlaying() {
        nowPlaying.handleNowPlayableSessionEnd()
    }

    private func getBody() -> String {
        playingTracks.sort { item1, item2 in
            if (item1.track.isMusic == item2.track.isMusic) {
                return item1.track.name > item2.track.name
            }
            if (item1.track.isMusic) {
                return true
            }
            if (item2.track.isMusic) {
                return false
            }
            return true
        }

        var sb = ""
        var wasMusic = false
        for i in 0 ..< playingTracks.count {
            let item  = playingTracks[i]
            let trackIsMusic = item.track.isMusic
            if (i > 0) {
                if (wasMusic && !trackIsMusic) {
                    sb.append(" | ")
                } else {
                    sb.append(", ")
                }
            }
            wasMusic = trackIsMusic
            sb.append(item.track.name)
        }
        return sb
    }
}
