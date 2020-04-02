//
//  UserCardViewModel.swift
//  Hush-SwiftUI
//
//  Created Dima Virych on 02.04.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI
import Combine

class UserCardViewModel: UserCardViewModeled {
    
    // MARK: - Properties

    @Published var age = 29
    @Published var image: UIImage = UIImage(named: "image4")!
    @Published var name: String = "Yolanda"
    @Published var selected: Bool = true
    
    func select() {

    }
}
