//
//  QueueTrack.swift
//  Capacitor
//
//  Created by Олег  Руссу on 09/10/2023.
//

import Foundation


public struct QueueTrack {

    public let id: String
    public let url: String
    public let name: String
    public let isMusic: Bool
    public let forcePlay: Bool

    public var assetId: String {
        get {
            url
        }
    }

    public init(jsObject: [String: Any]) {
        self.id  = String(jsObject["id"] as? Int ?? 0)
        self.url = jsObject["url"] as? String ?? ""
        self.name = jsObject["name"] as? String ?? ""
        self.isMusic = (jsObject["isMusic"] as? Int ?? 0) == 1
        self.forcePlay = (jsObject["forcePlay"] as? Int ?? 0) == 1
    }
}
