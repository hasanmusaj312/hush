//
//  AddPhotosViewModel.swift
//  Hush-SwiftUI
//
//  Created Dima Virych on 31.03.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import Combine
import AVFoundation
import UIKit

class AddPhotosViewModel: AddPhotosViewModeled {
    
    // MARK: - Properties

    @Published var messageLabel = "With Hush’s own Filters you can make \nyour photo as private as you like!"
    
    private let defaultMessage = "With Hush’s own Filters you can make \nyour photo as private as you like!"
    weak var picker: DVImagePicker?
    
    init(_ picker: DVImagePicker) {
        
        self.picker = picker
    }
    
    private var selectedImage: UIImage = UIImage()
    
    func addPhotoPressed() {
        
        if let vc = iOSApp.topViewController {
            picker?.showActionSheet(from: vc) { [weak self] result in
                
                switch result {
                case .failure:
                    self?.messageLabel = "You tapped “Don’t Allow” so we need to  take you to settings quick to allow us  access to your Camera Roll.\n\nThen  please return to the app and continue"
                case let .success(image):
                    self?.selectedImage = image
                }
            }
        }
    }
}
