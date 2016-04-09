//
//  ContentfulProvider.swift
//  EventBlank2-iOS
//
//  Created by Boris Bügling on 09/04/16.
//

import ContentfulPersistence
import RealmSwift

class Space: Object, CDAPersistedSpace {
    var lastSyncTimestamp: NSDate!
    var syncToken: String!
}

class Asset: Object, CDAPersistedAsset {
    var identifier: String!
    var internetMediaType: String!
    var url: String!
}

extension Object {
    static func allObjects() -> NSArray {
        let results = RealmProvider.eventRealm.objects(self)
        return Array(results)
    }
}

private class EventRealmManager: RealmManager {
    override var classForAssets: AnyClass {
        get { return Asset.self }
        set { }
    }

    override var classForSpaces: AnyClass {
        get { return Space.self }
        set { }
    }

    func currentRealm() -> RLMRealm {
        if let path = RealmProvider.eventRealm.configuration.path {
            return RLMRealm(path: path)
        }

        fatalError("Missing path to Realm")
    }
}

class ContentfulProvider {
    private lazy var manager: RealmManager = {
        let client = CDAClient(spaceKey: "unq8nskq5dfd", accessToken: "4966cd1977aed73a13fca673065ce96633f4fe2ddb074d0b4628c9e9b462d4b3")
        let manager = EventRealmManager(client: client)!

        manager.setClass(EventData.self, forEntriesOfContentTypeWithIdentifier: "event")

        return manager
    }()

    func sync() {
        manager.performSynchronizationWithSuccess({
            NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: kDidReplaceEventFileNotification, object: nil))
        }) { (_, error) in
            print("Error: \(error)")
        }
    }
}
