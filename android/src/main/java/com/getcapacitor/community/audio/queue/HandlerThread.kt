package com.getcapacitor.community.audio.queue

import android.os.Handler
import android.os.HandlerThread
import android.os.Looper


class HandlerThread(name: String) : HandlerThread(name) {
  init {

  }
  private var workerHandler: Handler? = null

  fun postTask(task: Runnable) {
    workerHandler!!.post(task)
  }

  fun postAfter(task: Runnable, after: Long) {
    workerHandler!!.postDelayed(task, after)
  }

  fun prepareHandler() {
    workerHandler = Handler(Looper.getMainLooper())
  }
}
