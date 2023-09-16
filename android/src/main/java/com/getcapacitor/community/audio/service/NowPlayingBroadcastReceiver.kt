package com.getcapacitor.community.audio.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NowPlayingBroadcastReceiver: BroadcastReceiver() {
    companion object {
        const val TAG = "NowPlayingBroadcastReceiver"
        const val ACTION_STOP_ALL = "org.dream.catcher.app.stap-all"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null) {
            return
        }
        val action = intent.action
        if (action == ACTION_STOP_ALL) {
            context?.sendBroadcast(Intent(context.packageName + ".stop_all"))
        }
    }
}