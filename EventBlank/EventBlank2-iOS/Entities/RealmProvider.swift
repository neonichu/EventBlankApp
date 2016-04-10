//
//  RealmProvider.swift
//  EventBlank2-iOS
//
//  Created by Marin Todorov on 2/19/16.
//  Copyright © 2016 Underplot ltd. All rights reserved.
//

import Foundation
import RealmSwift

class RealmProvider {
    
    static var eventRealm: Realm!
    static var appRealm: Realm!
    
    init(eventFile: String = eventDataFileName, appFile: String = appDataFileName) {

        let eventRealmConfig = RealmProvider.loadConfig(eventFile, path: FilePath(inLibrary: eventFile), defaultPath: FilePath(inBundle: eventFile), preferNewerSourceFile: true, readOnly: false)
        let appRealmConfig = RealmProvider.loadConfig(appFile, path: FilePath(inLibrary: appFile), defaultPath: FilePath(inBundle: appFile), preferNewerSourceFile: false, readOnly: false)
        
        guard let eventConfig = eventRealmConfig, let appConfig = appRealmConfig else {
            fatalError("Can't load the default realm")
        }
        
        Realm.Configuration.defaultConfiguration = eventConfig
        
        RealmProvider.eventRealm = try! Realm(configuration: eventConfig)
        RealmProvider.appRealm = try! Realm(configuration: appConfig)
    }
    
    private static func loadConfig(name: String, path targetPath: FilePath, defaultPath: FilePath? = nil, preferNewerSourceFile: Bool = false, readOnly: Bool = false) -> Realm.Configuration? {
        
        if let defaultPath = defaultPath {
            do {
                try defaultPath.copyOnceTo(targetPath)
                if preferNewerSourceFile {
                    try defaultPath.copyIfNewer(targetPath)
                }
            } catch let error as NSError {
                fatalError(error.description)
            }
        }
        
        var conf = Realm.Configuration()
        conf.readOnly = readOnly
        conf.path = targetPath.filePath
        conf.objectTypes = schemaForRealm(name)
        conf.schemaVersion = 1
        return conf
    }
    
    private static func schemaForRealm(name: String) -> [Object.Type] {
        switch name {
        case "appdata.realm":
            return [Favorites.self, ObjectId.self]
        default:
            return [Session.self, EventData.self, Speaker.self, Location.self, Text.self, Track.self,
                Space.self, Asset.self]
        }
    }
}
