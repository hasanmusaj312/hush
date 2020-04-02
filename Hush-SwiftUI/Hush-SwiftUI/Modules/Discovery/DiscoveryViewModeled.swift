//
//  DiscoveryViewModeled.swift
//  Hush-SwiftUI
//
//  Created Dima Virych on 02.04.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import Combine

protocol DiscoveryViewModeled: ObservableObject {
    
    var message: String { get set }
    
    func updateMessage()
}
