package com.getcapacitor.community.audio.service

public class FirebaseEventConstants {
    companion object {
        const val EVENT_TRACK_STARTED = "track_playback_started"
        const val EVENT_TRACK_COMPLETED = "track_playback_completed"

        const val KEY_TRACK_ID = "track_id"
        const val KEY_TRACK_NAME = "track_name"
        const val KEY_PLAYTIME_SECONDS = "track_playtime_seconds"
    }
}