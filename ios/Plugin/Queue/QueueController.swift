//
//  QueueController.swift
//  CapacitorNativeAudioStreamer
//
//  Created by Олег  Руссу on 09/10/2023.
//

import Foundation


final class QueueController {

    static let kEventPlaying = "track-playing"
    static let kEventTrackStop = "track-stop"
    static let kEventAllTracksStop = "all-tracks-stop"
    static let kEventTrackPause = "track-pause"

    weak var owner: NativeAudio!
    let id: String
    let useFade: Bool

    private var tracks: [QueueTrack] = []
    var index: Int = 0
    private var looping = false
    var player: QueuePlayer? = nil
    private var loopIndex = -1

    init(owner: NativeAudio, id: String, useFade: Bool) {
        self.owner = owner
        self.id = id
        self.useFade = useFade
    }

    func playQueue(
        jsTracks: [[String: Any]],
        startIndex: Int,
        startTime: Double,
        trailingTimeSeconds: Double,
        timerUpdateInterval: Double,
        volume: Float,
        loop: Bool
    ) {
        if (startIndex >= jsTracks.count) {
            return
        }

        tracks = []

        for i in 0 ..< jsTracks.count {
            let jsTrack = jsTracks[i]
            let track = QueueTrack(jsObject: jsTrack)
            tracks.append(track)
        }

        self.looping = loop
        self.loopIndex = -1

        player?.unload()
        index = startIndex

        if tracks.isEmpty {
            return
        }

        player = QueuePlayer(
            owner: self.owner,
            queueController: self,
            trailingTimeSeconds: trailingTimeSeconds,
            timerUpdateInterval: timerUpdateInterval,
            useFade: self.useFade
        )

        player!.setVolume(volume: volume)
        let track = tracks[index]
        player!.playTrack(track: track, time: startTime)
    }


    func updateQueue(jsTracks: [[String: Any]]) {
        if (jsTracks.isEmpty) {
            notifyStop(assetId: player?.getPlayingTrackId() ?? "")
            unload()
            return
        }
        var newTracks: [QueueTrack] = []
        let currentPlayingTrackId = player?.getPlayingTrackId() ?? ""
        var indexToSet = -1
        for i in 0 ..< jsTracks.count {
            let jsTrack = jsTracks[i]
            let track = QueueTrack(jsObject: jsTrack)
            newTracks.append(track)
            if (track.id != currentPlayingTrackId) {
                continue
            }
            indexToSet = i
        }
        tracks = []
        tracks.append(contentsOf: newTracks)

        if (indexToSet >= 0) {
            self.index = indexToSet
            return
        }

        if (index >= tracks.count) {
            index = tracks.count - 1
        }
    }

    func pause() -> Bool {
        if (player?.isPlaying() != true) {
            return false
        }
        player?.pause()
        return true
    }

    func resume() -> Bool {
        if (player?.isPaused() != true) {
            return false
        }
        player?.resume()
        return true
    }

    func isPlaying() -> Bool {
        player?.isPlaying() == true
    }

    func isPaused() -> Bool {
        player?.isPaused() == true
    }

    func toNextTrack() -> Bool {
        let nextTrack = requestNextTrackInternal()
        if (nextTrack == nil) {
            return false
        }
        player?.unload()
        player?.playTrack(track: nextTrack!)
        return true
    }

    func toPreviousTrack() -> Bool {
        let previousTrack = requestPreviousTrackInternal()
        if (previousTrack == nil) {
            return false
        }
        player?.unload()
        player?.playTrack(track: previousTrack!)
        return true
    }

    func seek(time: Double) -> Bool {
        if (player?.isPlaying() != true && player?.isPaused() != true) {
            return false
        }

        player?.seek(time: time)
        return true
    }

    func getCurrentTime() -> Double {
        player?.getCurrentTime() ?? 0.0
    }

    func setLoopIndex(index: Int, set: Bool) {
        if (loopIndex > tracks.count - 1) {
            return
        }

        loopIndex = set ? index : -1

        if (loopIndex >= 0 && self.index != loopIndex) {
            self.index = loopIndex
            player?.unload()
            player?.playTrack(track : tracks[index])
        }
    }

    func setVolume(volume: Float) -> Bool {
        player?.setVolume(volume: volume)
        return player != nil
    }

    func queueHasAssetId(assetId: String) -> Bool {
        tracks.first { $0.assetId == assetId } != nil
    }

    func requestNextTrack() -> QueueTrack? {
        return requestNextTrackInternal()
    }

    private func manageIndexToNext() -> Bool {
        if (loopIndex >= 0) {
            index = loopIndex
            return true
        }
        if (index == tracks.count - 1) {
            if (!maybeRemoveForcePlayTrackOnCurrentIndex(toNext: true)) {
                index = 0
            }
            if (looping) {
                return true
            }
            return false
        }
        if (!maybeRemoveForcePlayTrackOnCurrentIndex(toNext: true)) {
            index += 1
        }
        return true
    }

    private func manageIndexToPrevious() -> Bool {
        if (loopIndex >= 0) {
            index = loopIndex
            return true
        }
        if (index == 0) {
            if (looping) {
                _ = maybeRemoveForcePlayTrackOnCurrentIndex(toNext: false)
                index = tracks.count - 1
                return true
            }
            return false
        }
        _ = maybeRemoveForcePlayTrackOnCurrentIndex(toNext: false)
        index -= 1
        return true
    }

    private func maybeRemoveForcePlayTrackOnCurrentIndex(toNext: Bool) -> Bool {
        if (tracks.count == 1) {
            return false
        }
        let currentTrack = tracks[index]
        if !currentTrack.forcePlay {
            return false
        }

        tracks.remove(at: index)
        if toNext {
            if (index + 1 < tracks.count) {
                index += 1
                return true
            } else {
                if (looping) {
                    index = 0
                    return true
                }
            }
        }
        return false
    }

    private func requestNextTrackInternal() -> QueueTrack? {
        if (manageIndexToNext()) {
            if (!tracks.isEmpty) {
                if (index >= tracks.count) {
                    index = tracks.count - 1
                }
            } else {
                return nil
            }
            return tracks[index]
        }
        return nil
    }

    private func requestPreviousTrackInternal() -> QueueTrack? {
        if (manageIndexToPrevious()) {
            return tracks[index]
        }
        return nil
    }

    func unload() {
//            queueState = QueueState.IDLE
        player?.unload()
    }


    func completion(assetId: String) {
        if (tracks.first { $0.assetId == assetId } == nil) {
            return
        }

        if (player!.trailingTimeSeconds == 0.0 && (loopIndex >= 0 || looping)) {
            player!.unload()
            let nextTrack = requestNextTrackInternal()
            if nextTrack != nil {
                player!.playTrack(track: nextTrack!)
            } else {
                notifyStop(assetId: assetId)
            }
            return
        }

        let isPlayingAssetId = player?.isPlayingAssetId(assetId: assetId) == true
        let isTrailingAssetId = player?.isTrailingAssetId(assetId: assetId) == true

        if (isTrailingAssetId && isPlayingAssetId && (loopIndex >= 0 || looping)) {
            player?.unload(assetId: assetId)
            return
        }

        if (isPlayingAssetId) {
            notifyStop(assetId: assetId)
        }
        player?.unload(assetId: assetId)
    }

    func error(assetId: String) {
        if (tracks.first { $0.assetId == assetId } == nil) {
            return
        }
        player?.unload()
        notifyStop(assetId: assetId)
    }

    func notifyStop(assetId: String) {
        var data: [String: Any] = [:]
        data["id"] = id
        data["trackId"] = assetId
        owner.notifyListeners(QueueController.kEventTrackStop, data: data)
    }


}
