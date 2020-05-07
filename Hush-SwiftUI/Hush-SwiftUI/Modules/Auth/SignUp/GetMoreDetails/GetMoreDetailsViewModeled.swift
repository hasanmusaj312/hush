//
//  GetMoreDetailsViewModeled.swift
//  Hush-SwiftUI
//
//  Created Dima Virych on 31.03.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import Combine
import Foundation

protocol GetMoreDetailsViewModeled: ObservableObject {
    
    var whatFors: [String] { get set }
    var selectedWhatFor: Int { get set }
    
    var genders: [String] { get set }
    var selectedGender: Int { get set }
    
    var lookingFors: [String] { get set }
    var selectedLookingFors: Int { get set }
    
    var birthday: String { get set }
    
    func updateMessage()
}
