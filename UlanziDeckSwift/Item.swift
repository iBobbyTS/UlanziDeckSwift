//
//  Item.swift
//  UlanziDeckSwift
//
//  Created by iBobby on 2026-06-13.
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
