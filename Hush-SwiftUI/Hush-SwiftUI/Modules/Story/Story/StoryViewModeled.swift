//
//  StoryViewModeled.swift
//  Hush-SwiftUI
//
//  Created by Serge Vysotsky on 12.05.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI

protocol StoryViewModeled: ObservableObject {
    var currentStoryIndex: Int { get set }
    var storyMessage: String { get set }
    var stories: [Story] { get }
    var canSendMessages: Bool { get }
    var canReport: Bool { get }
    
    func getStoryImagePath() -> String
    func getStoryAvatarPath() -> String
    func getStoryTitle() -> String
    func getStoryTime() -> String
    
    func showNext()
    func blockUser()
    func reportProfile()
}

extension StoryViewModeled {
    var canTapNext: Bool {
        currentStoryIndex < stories.count - 1
    }
    
    func showNext() {
        currentStoryIndex += 1
    }
}

extension StoryViewModeled {
    func blockUser() {}
    func reportProfile() {}
}
