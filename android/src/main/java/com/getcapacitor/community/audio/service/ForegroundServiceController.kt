package com.getcapacitor.community.audio.service

import android.app.Activity
import android.content.Intent
import android.widget.Toast
import com.getcapacitor.community.audio.NativeAudio
import com.getcapacitor.community.audio.queue.QueueTrack

class ForegroundServiceController(private val owner: NativeAudio) {

    private val playingTracks = mutableListOf<NowPlayingItem>()

    private val predicate: (NowPlayingItem, QueueTrack) -> Boolean = { nowPlayingItem, track ->
        nowPlayingItem.track.assetId == track.assetId && nowPlayingItem.track.url == track.url
    }

    private var serviceIsRunning = false
    private var currentBody = ""

    fun playerStartedPlaying(track: QueueTrack) {
        owner.queueHandler.postTask {
            var item = playingTracks.firstOrNull { predicate(it, track) }
            if (item == null) {
                item = NowPlayingItem(track, 1)
                item.timePlayStarted = System.currentTimeMillis()
                playingTracks.add(item)
                startForegroundService(getBody())
                logStartedEvent(item, owner.activity)
                return@postTask
            }
            item.count += 1
        }
    }

    fun playerStoppedPlaying(track: QueueTrack) {
        owner.queueHandler.postTask {
            val item = playingTracks.firstOrNull { predicate(it, track) } ?: return@postTask
            if (item.count == 1) {
                logCompletedEvent(item, owner.activity)
                playingTracks.removeAll { predicate(it, track) }
            } else {
                item.count -= 1
            }
            if (playingTracks.isNotEmpty()) {
                val body = getBody()
                startForegroundService(body)
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
        if (currentBody == body && serviceIsRunning) {
            return
        }
        currentBody = body
        serviceIsRunning = true
        NowPlayingService.startCommand(owner.activity, true, body, if (playingTracks.size > 1) "Stop all" else "Stop");
    }

    private fun stopForegroundService() {
        serviceIsRunning = false
        NowPlayingService.startCommand(owner.activity, false, "", null)
    }

    private fun logCompletedEvent(item: NowPlayingItem, activity: Activity) {
        val startPlayingTime = item.timePlayStarted
        val timePlayed = System.currentTimeMillis() - startPlayingTime
        val totalSeconds = (timePlayed / 1000).toString()
        val intent = Intent(activity.packageName + "." + FirebaseEventConstants.EVENT_TRACK_COMPLETED)
        intent.putExtra(FirebaseEventConstants.KEY_TRACK_ID, item.track.id)
        intent.putExtra(FirebaseEventConstants.KEY_TRACK_NAME, item.track.name)
        intent.putExtra(FirebaseEventConstants.KEY_PLAYTIME_SECONDS, totalSeconds)
        intent.putExtra("event", FirebaseEventConstants.EVENT_TRACK_COMPLETED)
        activity.sendBroadcast(intent)
    }

    private fun logStartedEvent(item: NowPlayingItem, activity: Activity) {
        val intent = Intent(activity.packageName + "." + FirebaseEventConstants.EVENT_TRACK_STARTED)
        intent.putExtra(FirebaseEventConstants.KEY_TRACK_ID, item.track.id)
        intent.putExtra(FirebaseEventConstants.KEY_TRACK_NAME, item.track.name)
        intent.putExtra("event", FirebaseEventConstants.EVENT_TRACK_STARTED)
        activity.sendBroadcast(intent)
    }
}
