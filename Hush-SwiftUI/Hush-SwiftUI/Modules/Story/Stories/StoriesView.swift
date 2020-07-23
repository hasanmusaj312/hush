//
//  DiscoveryView.swift
//  Hush-SwiftUI
//
//  Created Dima Virych on 02.04.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI
import QGrid
import PartialSheet

var SafeAreaInsets: UIEdgeInsets {
    UIApplication.shared.windows.first?.rootViewController?.view.safeAreaInsets ?? .zero
}

protocol HeaderedScreen {
    
}

extension HeaderedScreen {
    
    func header<V: View>(_ list: [V]) -> some View {
        HStack {
            VStack(alignment: .leading) {
                
                ForEach(0..<list.count) {
                    list[$0]
                }
            }
            Spacer()
        }.padding(.leading, 25)
        .padding(.top, 5)
    }
}

struct StoriesView<ViewModel: StoriesViewModeled>: View, HeaderedScreen {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: ViewModel
    @State var userStories: [UIImage] = []
    @EnvironmentObject var modalPresenterManager: ModalPresenterManager
    @EnvironmentObject var app: App
    private let imagePicker = DVImagePicker()
    @State private var showsUserProfile = false

    init(viewModel: ViewModel, showingSetting: Bool) {
           self.viewModel = viewModel
           
           if !showingSetting {
               self.viewModel.viewStory { (result) in
               }
           }
         
       }
    // MARK: - Lifecycle
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: -14) {
                ForEach(0...10, id: \.self) { i in
                    HStack(spacing: -2) {
                        ForEach(0..<3, id: \.self) { j in
                            UserStoryCard(username: "Username", isMyStory: i == 0 && j == 0, isFirstStory: self.userStories.isEmpty, storyImage: self.userStories.last)
                                .rotationEffect(.degrees((i * 3 + j).isMultiple(of: 2) ? 0 : 5), anchor: .center)
                                .zIndex(j == 1 ? 3 : 0)
                                .offset(self.offset(row: i, column: j))
                                .onTapGesture {
                                    self.handleTap(i, j)
                                    
                            }
                        }
                    }.zIndex(self.zIndex(row: i))
                    .padding(.horizontal, 22)
                    .frame(width: SCREEN_WIDTH)
                }
            }.padding(.top, 22)
        }.background(
            NavigationLink(
                destination: StoryView(viewModel: StoryViewModel(), isNewStory: false).environmentObject(self.app).withoutBar(),
                isActive: $showsUserProfile,
                label: EmptyView.init
            )
        )
    }
    
    private func zIndex(row i: Int) -> Double {
        -Double(i)
    }
    
    private func offset(row i: Int, column j: Int) -> CGSize {
        let x: CGFloat
        switch (i, j) {
        case let (i, 0) where i != 0:
            x = -10
        case (0, 2):
            x = 5
        default:
            x = 0
        }
        
        return CGSize(width: x, height: 0)
    }
    
    func handleTap(_ i: Int, _ j: Int) {
        if i == 0 && j == 0 {
            showStoryPicker()
        } else {
            showStory()
        }
    }
    
    func showStory() {
        self.showsUserProfile = true
        //self.tapGesture(toggls: self.$showsUserProfile)
//        modalPresenterManager.present(style: .overFullScreen) {
//            StoryView(viewModel: StoryViewModel()).environmentObject(self.app)
//        }
    }
    
    func showMyStory(lastPick: Bool) {
        modalPresenterManager.present(style: .overFullScreen) {
            StoryView(viewModel: MyStoryViewModel(userStories, isLastPick: lastPick), isNewStory: true)
        }
    }
    
    func showStoryPicker() {
        let viewStory = UIAlertAction(title: "View Story", style: .default) { _ in self.showMyStory(lastPick: false) }
        let uploadStory = UIAlertAction(title: "Upload Story", style: .default) { _ in self.pickStory() }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        viewStory.isEnabled = !userStories.isEmpty
        let alert = TextAlert(style: .actionSheet, title: "Your Story Options", message: nil, actions: [
            viewStory,
            uploadStory,
            cancel
        ])
        
        modalPresenterManager.present(controller: UIAlertController(alert: alert))
    }
    
    func pickStory() {
        imagePicker.showActionSheet(from: modalPresenterManager.presenter!) { result in
            guard case let .success(image) = result else { return }
            self.userStories.append(image)
            self.modalPresenterManager.dismiss {
                self.showMyStory(lastPick: true)
            }
        }
    }
}

struct StoriesView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabBarView_Previews.previews
//        StoryView(username: "Username", isMyStory: false)
//            .frame(width: 124, height: 148)
//            .padding(50)
//            .previewLayout(.sizeThatFits)
//        Group {
//            NavigationView {
//                StoriesView(viewModel: StoriesViewModel())
//            }
//            NavigationView {
//                StoriesView(viewModel: StoriesViewModel())
//            }.previewDevice(.init(rawValue: "iPhone 8"))
//            NavigationView {
//                StoriesView(viewModel: StoriesViewModel())
//            }.previewDevice(.init(rawValue: "iPhone XS Max"))
//        }
    }
}
