//
//  App.swift
//  Hush-SwiftUI
//
//  Created by Dima Virych on 07.04.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import Foundation
import SwiftUI

class App: ObservableObject {
    
    @Published var logedIn = false
    @Published var showPremium = false
}