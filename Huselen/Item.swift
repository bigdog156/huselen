//
//  Item.swift
//  Huselen
//
//  Created by FinOS on 2/24/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
