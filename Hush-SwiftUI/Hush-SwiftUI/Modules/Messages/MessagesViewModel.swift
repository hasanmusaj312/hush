//
//  MessagesViewModel.swift
//  Hush-SwiftUI
//
//  Created Dima Virych on 06.04.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI
import Combine
import CoreLogic
import Fakery

class MessagesViewModel: MessagesViewModeled {
    
    
    // MARK: - Properties

    @Published var message = "Hellow World!"
    
    var searchQuery: String = ""
    
    private let storage = FakeStorage()
    
    var items: [HushConversation] {
        storage.getMessages()
    }
    
    func updateMessage() {

        message = "New Message"
    }
    
    func item(at index: Int) -> HushConversation {
        
        storage.getMessages()[index]
    }
    
    func numberOfItems() -> Int {
        
        storage.getMessages().count
    }
}


fileprivate class FakeStorage: HushConversationsStorage {
    
    func getMessages() -> [HushConversation] {
        
        storage
    }
    
    func search(by query: String) -> [HushConversation] {
        
        storage.filter { $0.username.contains(query) || $0.text.contains(query) }
    }
    
    func delete(message: HushConversation) {
        
        if let index = storage.firstIndex(where: { message.id == $0.id }) {
            storage.remove(at: index)
        }
    }
    
    init() {
        storage = Array(0..<10).map { _ in
            HushConversation(username: faker.name.firstName(), text: faker.lorem.paragraph(), imageURL: faker.internet.image(), time: faker.date.birthday(2, 55).timeIntervalSince1970, messages: Array(0..<10).map {
                HushMessage(userID: $0.isMultiple(of: 3) ? "SELF" : "DEF", text: faker.lorem.paragraph(), time: faker.date.birthday(2, 55).timeIntervalSince1970)
            })
        }
    }
    
    private let faker = Faker()
    private var storage: [HushConversation] = []
}
