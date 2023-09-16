package com.getcapacitor.community.audio.service

import android.widget.Toast
import com.getcapacitor.community.audio.NativeAudio
import com.getcapacitor.community.audio.queue.QueueTrack

class ForegroundServiceController(private val owner: NativeAudio) {

    private val playingTracks = mutableListOf<NowPlayingItem>()

    private val predicate: (NowPlayingItem, QueueTrack) -> Boolean = { nowPlayingItem, track ->
        nowPlayingItem.track.assetId == track.assetId && nowPlayingItem.track.url == track.url
    }

    fun playerStartedPlaying(track: QueueTrack) {
        owner.queueHandler.postTask {
            var item = playingTracks.firstOrNull { predicate(it, track) }
            if (item == null) {
                item = NowPlayingItem(track, 1)
                item.timePlayStarted = System.currentTimeMillis()
                playingTracks.add(item)
                startForegroundService(getBody())
                return@postTask
            }
            item.count += 1
        }
    }

    fun playerStoppedPlaying(track: QueueTrack) {
        owner.queueHandler.postTask {
            val item = playingTracks.firstOrNull { predicate(it, track) } ?: return@postTask
            if (item.count == 1) {
                logPlayedEvent(item)
                playingTracks.removeAll { predicate(it, track) }
            } else {
                item.count -= 1
            }
            if (playingTracks.isNotEmpty()) {
                startForegroundService(getBody())
                return@postTask
            }
            stopForegroundService()
        }
    }

    private fun getBody(): String {
        playingTracks.sortWith { item1, item2 ->
            if (item1.track.isMusic == item2.track.isMusic) {
                return@sortWith item1.track.name.compareTo(item2.track.name)
            }
            if (item1.track.isMusic) {
                return@sortWith -1
            }
            if (item2.track.isMusic) {
                return@sortWith 1
            }
            0
        }
        val sb = StringBuilder()
        var wasMusic = false
        for (i in playingTracks.indices) {
            val item  = playingTracks[i]
            val trackIsMusic = item.track.isMusic
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
        return sb.toString()
    }

    private fun startForegroundService(body: String) {
        NowPlayingService.startCommand(owner.activity, true, body, if (playingTracks.size > 1) "Stop all" else "Stop");
    }

    private fun stopForegroundService() {
        NowPlayingService.startCommand(owner.activity, false, "", null)
    }

    private fun logPlayedEvent(item: NowPlayingItem) {
        val startPlayingTime = item.timePlayStarted
        val timePlayed = System.currentTimeMillis() - startPlayingTime
        val totalSeconds = timePlayed / 1000
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        val durationString = "$minutes:$seconds"
//        Toast.makeText(owner.context, "${item.track.name} played ${durationString}", Toast.LENGTH_LONG).show()
    }
}
