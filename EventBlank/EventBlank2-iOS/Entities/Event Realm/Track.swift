//
//  Track.swift
//  EventBlank2-iOS
//
//  Created by Marin Todorov on 2/20/16.
//  Copyright © 2016 Underplot ltd. All rights reserved.
//

import Foundation
import RealmSwift
import ContentfulDeliveryAPI

class Track: Object, CDAPersistedEntry {
    dynamic var identifier = ""
    
    dynamic var track = ""
    dynamic var trackDescription = ""
    
}