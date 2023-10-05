'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@capacitor/core');

const NativeAudio$1 = core.registerPlugin('NativeAudio', {
    web: () => Promise.resolve().then(function () { return web; }).then(m => new m.NativeAudioWeb()),
});

class AudioAsset {
    constructor(audio) {
        this.audio = audio;
    }
}

class NativeAudioWeb extends core.WebPlugin {
    constructor() {
        super({
            name: 'NativeAudio',
            platforms: ['web'],
        });
    }
    getQueuePlayingIndex(options) {
        options.id;
        throw new Error('Method not implemented.');
    }
    async resume(options) {
        const audio = this.getAudioAsset(options.assetId).audio;
        if (audio.paused) {
            return audio.play();
        }
    }
    async pause(options) {
        const audio = this.getAudioAsset(options.assetId).audio;
        return audio.pause();
    }
    async getCurrentTime(options) {
        const audio = this.getAudioAsset(options.assetId).audio;
        return { currentTime: audio.currentTime };
    }
    async getDuration(options) {
        const audio = this.getAudioAsset(options.assetId).audio;
        if (Number.isNaN(audio.duration)) {
            throw 'no duration available';
        }
        if (!Number.isFinite(audio.duration)) {
            throw 'duration not available => media resource is streaming';
        }
        return { duration: audio.duration };
    }
    async configure(options) {
        throw `configure is not supported for web: ${JSON.stringify(options)}`;
    }
    async preload(options) {
        var _a;
        if (NativeAudioWeb.AUDIO_ASSET_BY_ASSET_ID.has(options.assetId)) {
            throw 'AssetId already exists. Unload first if like to change!';
        }
        if (!((_a = options.assetPath) === null || _a === void 0 ? void 0 : _a.length)) {
            throw 'no assetPath provided';
        }
        if (!options.isUrl && !new RegExp('^/?' + NativeAudioWeb.FILE_LOCATION).test(options.assetPath)) {
            const slashPrefix = options.assetPath.startsWith('/') ? '' : '/';
            options.assetPath = `${NativeAudioWeb.FILE_LOCATION}${slashPrefix}${options.assetPath}`;
        }
        const audio = new Audio(options.assetPath);
        audio.autoplay = false;
        audio.loop = false;
        audio.preload = 'auto';
        if (options.volume) {
            audio.volume = options.volume;
        }
        NativeAudioWeb.AUDIO_ASSET_BY_ASSET_ID.set(options.assetId, new AudioAsset(audio));
    }
    async play(options) {
        var _a;
        const audio = this.getAudioAsset(options.assetId).audio;
        await this.stop(options);
        audio.loop = false;
        audio.currentTime = (_a = options.time) !== null && _a !== void 0 ? _a : 0;
        return audio.play();
    }
    async loop(options) {
        const audio = this.getAudioAsset(options.assetId).audio;
        await this.stop(options);
        audio.loop = true;
        return audio.play();
    }
    async stop(options) {
        const audio = this.getAudioAsset(options.assetId).audio;
        audio.pause();
        audio.loop = false;
        audio.currentTime = 0;
    }
    async unload(options) {
        await this.stop(options);
        NativeAudioWeb.AUDIO_ASSET_BY_ASSET_ID.delete(options.assetId);
    }
    async setVolume(options) {
        if (typeof (options === null || options === void 0 ? void 0 : options.volume) !== 'number') {
            throw 'no volume provided';
        }
        const audio = this.getAudioAsset(options.assetId).audio;
        audio.volume = options.volume;
    }
    async isPlaying(options) {
        const audio = this.getAudioAsset(options.assetId).audio;
        return { isPlaying: !audio.paused };
    }
    getAudioAsset(assetId) {
        this.checkAssetId(assetId);
        if (!NativeAudioWeb.AUDIO_ASSET_BY_ASSET_ID.has(assetId)) {
            throw `no asset for assetId "${assetId}" available. Call preload first!`;
        }
        return NativeAudioWeb.AUDIO_ASSET_BY_ASSET_ID.get(assetId);
    }
    checkAssetId(assetId) {
        if (typeof assetId !== 'string') {
            throw 'assetId must be a string';
        }
        if (!(assetId === null || assetId === void 0 ? void 0 : assetId.length)) {
            throw 'no assetId provided';
        }
    }
    cancelSleepTimer() {
        return Promise.resolve(undefined);
    }
    getCurrentQueueIndex() {
        return Promise.resolve(0);
    }
    getQueueTrackCurrentTime(id) {
        console.log(id);
        return Promise.resolve(0);
    }
    isQueuePaused(options) {
        options.id;
        return Promise.resolve({ isQueuePaused: false });
    }
    isQueuePlaying(options) {
        options.id;
        return Promise.resolve({ isQueuePlaying: false });
    }
    pauseQueue(options) {
        options.id;
        return Promise.resolve(undefined);
    }
    playNextQueueTrack(id) {
        console.log(id);
        return Promise.resolve(undefined);
    }
    playPreviousQueueTrack(id) {
        console.log(id);
        return Promise.resolve(undefined);
    }
    // @ts-ignore
    playQueue(options) {
        options.id;
        return Promise.resolve(undefined);
    }
    queueHasTrackWith(options) {
        options.id;
        return Promise.resolve({ has: false });
    }
    resumeQueue(options) {
        options.id;
        return Promise.resolve(undefined);
    }
    seekQueue(options) {
        options.id;
        return Promise.resolve(undefined);
    }
    setQueueLoopIndex(options) {
        options.id;
        return Promise.resolve(0);
    }
    setQueueVolume(options) {
        options.id;
        return Promise.resolve(undefined);
    }
    setSleepTimer(options) {
        options.time;
        return Promise.resolve(undefined);
    }
    unloadQueue(options) {
        options.id;
        return Promise.resolve(undefined);
    }
}
NativeAudioWeb.FILE_LOCATION = 'assets/sounds';
NativeAudioWeb.AUDIO_ASSET_BY_ASSET_ID = new Map();
const NativeAudio = new NativeAudioWeb();

var web = /*#__PURE__*/Object.freeze({
    __proto__: null,
    NativeAudioWeb: NativeAudioWeb,
    NativeAudio: NativeAudio
});

exports.NativeAudio = NativeAudio$1;
//# sourceMappingURL=plugin.cjs.js.map
