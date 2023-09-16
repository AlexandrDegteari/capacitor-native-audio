package com.getcapacitor.community.audio.queue

import org.json.JSONObject

class QueueTrack(val url: String, val name: String, val isMusic: Boolean) {
    val assetId: String
        get() {
            return url
        }

    constructor(jsObject: JSONObject) : this(
        url = kotlin.run {
            val key = "url"
            if (jsObject.has(key)) {
                return@run jsObject.getString(key) ?: ""
            }
            return@run ""
        },
        name = kotlin.run {
            val key = "name"
            if (jsObject.has(key)) {
                return@run jsObject.getString(key) ?: ""
            }
            return@run ""
        },
        isMusic = kotlin.run {
            val key = "isMusic"
            if (jsObject.has(key)) {
                return@run jsObject.getBoolean(key)
            }
            return@run false
        }
    )
}
