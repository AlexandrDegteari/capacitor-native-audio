//
//  Timer2.swift
//  CapacitorNativeAudioStreamer
//
//  Created by Олег  Руссу on 09/10/2023.
//

import Foundation


final class Timer2 {

    let interval: Double
    var isRunning = false
    var workItem: DispatchWorkItem!

    var function: (() -> ())?

    init(interval: Double, function: (() -> ())?) {
        self.interval = interval
        self.function = function
    }

    func start() {
        workItem?.cancel()
        workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            function?()
            if isRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
                return
            }
            if workItem.isCancelled {
                return
            }
            workItem?.cancel()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
        isRunning = true
    }

    func invalidate() {
        if workItem?.isCancelled == false {
            workItem?.cancel()
        }
        isRunning = false
    }
}
