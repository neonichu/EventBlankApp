//
//  ContentfulProvider.swift
//  EventBlank2-iOS
//
//  Created by Boris Bügling on 09/04/16.
//

import ContentfulPersistence
import RealmSwift

class Asset: Object, CDAPersistedAsset {
    dynamic var identifier: String!
    dynamic var internetMediaType: String!
    dynamic var url: String!
}

class Space: Object, CDAPersistedSpace {
    dynamic var lastSyncTimestamp: NSDate!
    dynamic var syncToken: String!
}

private class EventRealmManager: RealmManager {
    override var classForAssets: AnyClass { get { return Asset.self } set { } }
    override var classForSpaces: AnyClass { get { return Space.self } set { } }

    func currentRealm() -> RLMRealm {
        if let path = RealmProvider.eventRealm.configuration.path {
            return RLMRealm(path: path)
        }

        fatalError("Missing path to Realm")
    }
}

extension Object {
    static func allObjects() -> NSArray {
        let results = RealmProvider.eventRealm.objects(self)
        return Array(results)
    }

    static func objectsWithPredicate(predicate: NSPredicate) -> NSArray {
        let results = RealmProvider.eventRealm.objects(self).filter(predicate)
        return Array(results)
    }
}

class ContentfulProvider {
    private lazy var manager: RealmManager = {
        let client = CDAClient(spaceKey: "unq8nskq5dfd", accessToken: "4966cd1977aed73a13fca673065ce96633f4fe2ddb074d0b4628c9e9b462d4b3")
        let manager = EventRealmManager(client: client)!

        manager.setClass(EventData.self, forEntriesOfContentTypeWithIdentifier: "event")

        return manager
    }()

    private func fetchAsset(asset: Asset?, completion: (UIImage) -> ()) {
        guard let asset = asset, urlString = asset.url, url = NSURL(string: urlString) else { return }

        let task = NSURLSession.sharedSession().dataTaskWithURL(url) { data, _, _ in
            if let data = data, image = UIImage(data: data) {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(image)
                }
            }
        }

        task.resume()
    }

    func sync() {
        manager.performSynchronizationWithSuccess({
            NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: kDidReplaceEventFileNotification, object: nil))

            RealmProvider.eventRealm.objects(EventData).forEach { data in
                if data.logo != nil { return }
                self.fetchAsset(data.eventLogo) { image in
                    try! RealmProvider.eventRealm.write {
                        data.logo = image
                    }
                }
            }

            RealmProvider.eventRealm.objects(Speaker).forEach { data in
                if data.photo != nil { return }
                self.fetchAsset(data.speakerPhoto) { image in
                    try! RealmProvider.eventRealm.write {
                        data.photo = image
                    }
                }
            }
        }) { (_, error) in
            print("Error: \(error)")
        }
    }
}
