//
//  TabBarView.swift
//  Hush-SwiftUI
//
//  Created by Serge Vysotsky on 11.05.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI
import PartialSheet

enum HushTabs: Int, CaseIterable, Identifiable {
    case discoveries
    case stories
    case carusel
    case chats
    case profile
    
    var id: Int { rawValue }
    
    fileprivate var image: Image {
        Image("\(self)Tab")
    }
}

struct TabBarView<Content: View>: View {
    @EnvironmentObject private var partialSheetManager: PartialSheetManager
    @EnvironmentObject var app: App
    @Binding var selectedTab: HushTabs
    @State var isChatUnread = false
    let content: Content

    init(selectedTab: Binding<HushTabs>, @ViewBuilder content: () -> Content) {
        _selectedTab = selectedTab
        self.content = content()
    }
    
    func setChatUnRead(enabled: Bool) {
        
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
            HStack(alignment: .center, spacing: 0) {
                ForEach(HushTabs.allCases) { tab in
                    Button(action: {
                        self.selectedTab = tab
                        self.partialSheetManager.closePartialSheet()
                        self.app.isShowingSetting = false
                    }) {
                        Spacer()
                        if tab == HushTabs.chats {
                            ZStack {
                                tab.image
                                .renderingMode(.template)
                                .foregroundColor(tab == self.selectedTab ? .hOrange : Color(0x8E8786))
                                    .overlay(Circle().fill(Color.green).frame(width: 15, height: 15).opacity( self.$isChatUnread.wrappedValue ? 1.0 : 0.0), alignment: .bottomTrailing)
                            }
                        } else {
                            tab.image
                                .renderingMode(.template)
                                .foregroundColor(tab == self.selectedTab ? .hOrange : Color(0x8E8786))
                        }
                        Spacer()
                    }
                }.offset(x: 0, y: 3)
            }.padding(.horizontal, 20)
            .frame(height: 70)
            .background(Color.black.edgesIgnoringSafeArea(.all))
        }.background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TabBarView(selectedTab: .constant(.carusel), content: { Color.gray })
        }.previewLayout(.sizeThatFits)
    }
}
