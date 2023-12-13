//
//  AudioAsset.swift
//  Plugin
//
//  Created by priyank on 2020-05-29.
//  Copyright © 2020 Max Lynch. All rights reserved.
//

import AVFoundation

public class AudioAsset: NSObject, AVAudioPlayerDelegate {

    var channels: NSMutableArray = NSMutableArray()
    var playIndex: Int = 0
    var assetId: String = ""
    var initialVolume: NSNumber = 1.0

    var trailing = false

    let FADE_STEP: Float = 0.05
    let FADE_DELAY: Float = 0.08

    weak var owner: NativeAudio!
    
    let queueTrack: QueueTrack
    weak var queuePlayer: QueuePlayer!
    
    var isPaused: Bool = false


    init(
        owner: NativeAudio,
        queueTrack: QueueTrack,
        queuePlayer: QueuePlayer,
        withAssetId assetId:String,
        withPath path: String!,
        withChannels channels: NSNumber!,
        withVolume volume: NSNumber!,
        useFade: Bool!
    ) {
        
        self.owner = owner
        self.queueTrack = queueTrack
        self.queuePlayer = queuePlayer
        self.assetId = assetId
        self.channels = NSMutableArray.init(capacity: channels as! Int)
        super.init()

        let pathUrl: NSURL! = NSURL(string: path)

        for _ in 0..<channels.intValue {
            let player: Player! = Player(url: pathUrl as URL, useFade: useFade)

            player.avPlayer.volume = volume.floatValue
            self.channels.addObjects(from: [player as Any])
            if channels == 1 {
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.avPlayer.currentItem, queue: .main) { [weak self] _ in
                    guard let self = self else { return }
                    queuePlayer.queueController?.completion(assetId: self.assetId)
                    if trailing {
                        return
                    }
                    owner.nowPlayingContoroller.playerStoppedPlaying(track: self.queueTrack)
                }
            }
        }
    }

    func getCurrentTime() -> TimeInterval {
        if channels.count != 1 {
            return 0
        }

        let player: Player = channels.object(at: playIndex) as! Player
        let seconds = CMTimeGetSeconds(player.avPlayer.currentTime())
        return seconds
    }

    func getDuration() -> TimeInterval {
        if channels.count != 1 {
            return 0
        }

        let player: Player = channels.object(at: playIndex) as! Player
        guard let currentTime = player.avPlayer.currentItem else { return 0 }
        let dur = currentTime.asset.duration
        let seconds = CMTimeGetSeconds(dur)
        return seconds
    } 
     func getList() -> NSMutableArray {

            return channels
        }

    func play(time: TimeInterval) {
        let player: Player = channels.object(at: playIndex) as! Player
        player.avPlayer.currentItem?.seek(to: CMTimeMakeWithSeconds(time, preferredTimescale: 60000), completionHandler: nil)
        player.avPlayer.play()
        playIndex = Int(truncating: NSNumber(value: playIndex + 1))
        playIndex = Int(truncating: NSNumber(value: playIndex % channels.count))
        isPaused = false
        owner.nowPlayingContoroller.playerStartedPlaying(track: self.queueTrack)
    }

    func playWithFade(time: TimeInterval) {
        self.play(time: time)
    }

    func pause() {
        let player: Player = channels.object(at: playIndex) as! Player
        player.avPlayer.pause()
        isPaused = true
        owner.nowPlayingContoroller.playerStoppedPlaying(track: self.queueTrack)
    }

    func resume() {
        let player: Player = channels.object(at: playIndex) as! Player

//        let timeOffset = player.deviceCurrentTime + 0.01
        player.avPlayer.play()
        isPaused = false
        owner.nowPlayingContoroller.playerStartedPlaying(track: queueTrack)
    }

    func stop() {
        for i in 0..<channels.count {
            let player: Player! = channels.object(at: i) as? Player
            player.avPlayer.pause()
//            player.avPlayer.replaceCurrentItem(with: nil)
        }
        owner.nowPlayingContoroller.playerStoppedPlaying(track: self.queueTrack)
    }

    func stopWithFade() {
        stop()
    }
    
    func seekTo(time: Double) {
        let player: Player! = channels.object(at: Int(playIndex)) as? Player
        player.avPlayer.seek(to: CMTime(seconds: time, preferredTimescale: CMTimeScale(1000)))
    }

    func loop() {
        let player: Player! = channels.object(at: Int(playIndex)) as? Player
        player.avPlayer.play()
        player.isLoop = true
        playIndex = Int(truncating: NSNumber(value: playIndex + 1))
        playIndex = Int(truncating: NSNumber(value: playIndex % channels.count))
    }

    func unload() {
        self.stop()

//        for i in 0..<channels.count {
//            var player: AVAudioPlayer! = channels.object(at: i) as? AVAudioPlayer
//
//            player = nil
//        }

        channels = NSMutableArray()
    }

    func setVolume(volume: NSNumber!) {
        for i in 0..<channels.count {
            let player: Player! = channels.object(at: i) as? Player
            player.avPlayer.volume = volume.floatValue
        }
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        NSLog("playerDidFinish")
        queuePlayer.queueController?.completion(assetId: self.assetId)
    }

    func playerDecodeError(player: AVAudioPlayer!, error: NSError!) {
        queuePlayer.queueController?.error(assetId: self.assetId)
    }

    func isPlaying() -> Bool {
        if channels.count != 1 {
            return false
        }

        let player: Player = channels.object(at: playIndex) as! Player

        return player.avPlayer.rate != 0 && player.avPlayer.error == nil
    }

    @objc func notifyStop() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            NSLog("notify stop")
            let player: Player! = self.channels.object(at: Int(self.playIndex)) as? Player
            if player.isLoop {
                player.avPlayer.play()
            } else {
                self.owner.notifyListeners("complete", data: ["assetId": self.assetId])
            }

        }
    }
}



class Player {
    var avPlayer: AVPlayer!
    var asset: AVAsset!
    var isLoop: Bool = false

    init(url: URL, useFade: Bool) {
        asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        if useFade {
            let duration = asset.duration
            let durationInSeconds = CMTimeGetSeconds(duration)
            let params = AVMutableAudioMixInputParameters(track: asset.tracks.first! as AVAssetTrack)
            let firstSecond = CMTimeRangeMake(start: CMTimeMakeWithSeconds(0, preferredTimescale: 1000), duration: CMTimeMakeWithSeconds(1.0, preferredTimescale: 1000))
            let lastSecond = CMTimeRangeMake(start: CMTimeMakeWithSeconds(durationInSeconds - 1.3, preferredTimescale: 1000), duration: CMTimeMakeWithSeconds(1, preferredTimescale: 1000))
            params.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: firstSecond)
            params.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: lastSecond)
            let mix = AVMutableAudioMix()
            mix.inputParameters = [params]
            item.audioMix = mix
        }
        avPlayer = AVPlayer(playerItem: item)
    }
}
