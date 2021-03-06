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
    @State var isUpdate = false
    
    init(viewModel: ViewModel, showingSetting: Bool) {
        self.viewModel = viewModel
           
        if !showingSetting {
            self.viewModel.isShowingIndicator = true
            self.viewModel.viewStories { (result) in
                viewModel.isShowingIndicator = false
            }
       }
   }
    // MARK: - Lifecycle
    
    var body: some View {
        ZStack{
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: -14) {
                    ForEach(0...self.viewModel.storyList.count / 3, id: \.self) { i in
                        HStack(spacing: -10) {
                            ForEach(0..<3, id: \.self) { j in
                                HStack(spacing: -10) {
                                    if (i * 3 + j < self.viewModel.storyList.count) {
                                        UserStoryCard(username: self.viewModel.storyList[i * 3 + j].name ?? "",
                                                      isMyStory: i == 0 && j == 0,
                                                      isFirstStory: self.userStories.isEmpty,
                                                      storyImage: self.userStories.last,
                                                      imagePath: self.viewModel.storyList[i * 3 + j].story,
                                                      iconPath: self.viewModel.storyList[i * 3 + j].profile_photo)
                                            .frame(width: SCREEN_WIDTH / 3, height: SCREEN_WIDTH / 3 + 20)
                                            .rotationEffect(.degrees((i * 3 + j).isMultiple(of: 2) ? 0 : 5), anchor: .center)
                                            .zIndex(j == 1 ? 3 : 0)
                                            .offset(self.offset(row: i, column: j))
                                            .onTapGesture {
                                                self.handleTap(i, j)
                                        }
                                    }
                                }
                            }
                        }.zIndex(self.zIndex(row: i))
                        .padding(.horizontal, 22)
                            .frame(width: SCREEN_WIDTH, alignment: .leading)
                            .padding(.leading, -20)
                    }
                }.padding(.top, 22)
            }
            .background(
                NavigationLink(
                    destination: StoryView(viewModel: StoryViewModel(stories: self.viewModel.myStoryList, index: self.viewModel.selectedStoryIndex), isNewStory: false)
                        .withoutBar()
                        .onDisappear(perform: {
                            if (Common.storyUpdated()) {
                                Common.setStoryUpdate(update: false)
                                self.viewModel.isShowingIndicator = true
                                self.viewModel.viewStories { (result) in
                                    self.viewModel.isShowingIndicator = false
                                }
                            }
                        }),
                    isActive: $showsUserProfile,
                    label: EmptyView.init
                )
//                    .onDisappear(perform: {
//                    self.viewModel.isShowingIndicator = true
//                    self.viewModel.viewStories { (result) in
//                        self.viewModel.isShowingIndicator = false
//                    }
//                })
            )
            
            HushIndicator(showing: self.viewModel.isShowingIndicator)

        }
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
            self.viewModel.selectedStoryIndex = i * 3 + j
            let stories = self.viewModel.storyList[self.viewModel.selectedStoryIndex]
            if let userId = stories.id {
                self.viewModel.selectedStoryIndex = 0
                showStory(userId: userId)
            }
        }
    }
    
    func showStory(userId: String) {
        self.viewModel.viewStory(userId: userId) { (result) in
            if (result) {
                self.showsUserProfile = true
            }
        }
        
        //self.tapGesture(toggls: self.$showsUserProfile)
//        modalPresenterManager.present(style: .overFullScreen) {
//            StoryView(viewModel: StoryViewModel()).environmentObject(self.app)
//        }
    }
    
    func showMyStory(image: UIImage) {
        self.viewModel.isShowingIndicator = true
        self.viewModel.uploadImage(userImage: image) { (dic, error) in
            if error == nil {
                let imagePath = dic!["path"] as! String
                let imageThumb = dic!["thumb"] as! String
                self.viewModel.uploadStory(imagePath: imagePath, imageThumb: imageThumb) { (stories, error) in
                    self.viewModel.isShowingIndicator = false
                    if let stories = stories {
                        self.viewModel.selectedStoryIndex = stories.count - 1
                    }
                    let user = Common.userInfo()
                    if let userId = user.id {
                        self.showStory(userId: userId)
                    }
                }
            } else {
                self.viewModel.isShowingIndicator = false
            }
        }

    }
    
    func showStoryPicker() {
        let viewStory = UIAlertAction(title: "View Story", style: .default) { _ in
            //self.showMyStory(lastPick: false)
            self.viewModel.selectedStoryIndex = 0
            let user = Common.userInfo()
            if let userId = user.id {
                self.showStory(userId: userId)
            }
        }
        
        let uploadStory = UIAlertAction(title: "Upload Story", style: .default) { _ in self.pickStory() }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        //viewStory.isEnabled = !userStories.isEmpty
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
            //self.userStories.append(image)
            self.modalPresenterManager.dismiss {
                self.showMyStory(image: image)
            }
        }
    }
}

struct StoriesView_Previews: PreviewProvider {
    static var previews: some View {
//        RootTabBarView_Previews.previews
//        StoryView(username: "Username", isMyStory: false)
//            .frame(width: 124, height: 148)
//            .padding(50)
//            .previewLayout(.sizeThatFits)
       
        NavigationView {
            StoriesView(viewModel: StoriesViewModel(), showingSetting: false)
        }
    }
}
