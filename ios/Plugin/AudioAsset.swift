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
    var fadeDelay: NSNumber = 1.0

    let FADE_STEP: Float = 0.05
    let FADE_DELAY: Float = 0.08

    var owner: NativeAudio

    init(
        owner: NativeAudio,
        withAssetId assetId:String, withPath path: String!, withChannels channels: NSNumber!, withVolume volume: NSNumber!, withFadeDelay delay: NSNumber!) {

        self.owner = owner
        self.assetId = assetId
        self.channels = NSMutableArray.init(capacity: channels as! Int)

        super.init()

        let pathUrl: NSURL! = NSURL(string: path)

        for _ in 0..<channels.intValue {
            let player: Player! = Player(url: pathUrl as URL)

            player.avPlayer.volume = volume.floatValue
            self.channels.addObjects(from: [player as Any])
            if channels == 1 {
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.avPlayer.currentItem, queue: .main) { [weak self] _ in
                    player.avPlayer.seek(to: CMTime.zero)
                    player.avPlayer.play()
                }
                NotificationCenter.default.addObserver(self, selector: #selector(notifyStop), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.avPlayer.currentItem)
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
    }

    func playWithFade(time: TimeInterval) {
        self.play(time: time)
    }

    func pause() {
        let player: Player = channels.object(at: playIndex) as! Player
        player.avPlayer.pause()
    }

    func resume() {
        let player: Player = channels.object(at: playIndex) as! Player

//        let timeOffset = player.deviceCurrentTime + 0.01
        player.avPlayer.play()
    }

    func stop() {
        for i in 0..<channels.count {
            let player: Player! = channels.object(at: i) as? Player
            player.avPlayer.pause()
//            player.avPlayer.replaceCurrentItem(with: nil)
        }
    }

    func stopWithFade() {
        stop()
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
    }

    func playerDecodeError(player: AVAudioPlayer!, error: NSError!) {

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



fileprivate class Player {
    var avPlayer: AVPlayer!
    var isLoop: Bool = false

    init(url: URL) {
        avPlayer = AVPlayer(url: url)
    }
}
