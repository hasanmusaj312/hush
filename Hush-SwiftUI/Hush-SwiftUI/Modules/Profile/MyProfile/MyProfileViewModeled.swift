//
//  MyProfileViewModeled.swift
//  Hush-SwiftUI
//
//  Created Dima Virych on 07.04.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import Combine

protocol MyProfileViewModeled: ObservableObject {
    
    var message: String { get set }
    
    func updateMessage()
}