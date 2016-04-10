//
//  Session.swift
//  EventBlank2-iOS
//
//  Created by Marin Todorov on 2/20/16.
//  Copyright © 2016 Underplot ltd. All rights reserved.
//

import Foundation
import RealmSwift
import ContentfulDeliveryAPI

class Session: Object, CDAPersistedEntry {
    dynamic var identifier = ""

    dynamic var uuid = NSUUID().UUIDString
    
    dynamic var title = ""
    dynamic var sessionDescription = ""
    
    dynamic var beginTime: NSDate?
    dynamic var lengthInMinutes: Int = 0
    
    dynamic var track: Track?
    dynamic var location: Location?
    let speakers = List<Speaker>()
}