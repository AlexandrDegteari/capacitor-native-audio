#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Define the plugin using the CAP_PLUGIN Macro, and
// each method the plugin supports using the CAP_PLUGIN_METHOD macro.
CAP_PLUGIN(NativeAudio, "NativeAudio",
             CAP_PLUGIN_METHOD(getList, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(configure, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(preload, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(play, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(stop, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(loop, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(pause, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(resume, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(unload, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(setVolume, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(getCurrentTime, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(getDuration, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(isPlaying, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(playQueue, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(isQueuePlaying, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(getQueuePlayingTrackId, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(isQueuePaused, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(pauseQueue, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(resumeQueue, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(seekQueue, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(playNextQueueTrack, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(playPreviousQueueTrack, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(getQueuePlayingIndex, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(setQueueLoopIndex, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(setQueueVolume, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(queueHasTrackWith, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(updateQueue, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(unloadQueue, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(setSleepTimer, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(cancelSleepTimer, CAPPluginReturnPromise);
             CAP_PLUGIN_METHOD(requestNotificationPermission, CAPPluginReturnPromise);
)
