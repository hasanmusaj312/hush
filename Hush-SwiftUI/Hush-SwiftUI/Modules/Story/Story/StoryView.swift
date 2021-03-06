//
//  StoryView.swift
//  Hush-SwiftUI
//
//  Created by Serge Vysotsky on 11.05.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI
import SDWebImageSwiftUI

struct StoryView<ViewModel: StoryViewModeled>: View {
    @ObservedObject var viewModel: ViewModel
    var isNewStory = false
    
    @State private var keyboardHeight: CGFloat = 0
    @State private var showEdit = false
    @State private var likedStory = false
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var modalPresenterManager: ModalPresenterManager
    @EnvironmentObject private var app: App
    @State private var showsUserProfile = false
    @Environment(\.presentationMode) var mode

    var body: some View {
        GeometryReader(content: content)
    }
    
    var dragToClose: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .global).onChanged { value in
            if value.translation.height > 50 {
                //self.modalPresenterManager.dismiss()
            }
        }
    }
    
    private func content(_ proxy: GeometryProxy) -> some View {
        ZStack {
            WebImage(url: URL(string: self.viewModel.getStoryImagePath()))
                .resizable()
                .frame(proxy)
                .scaledToFill()
                .clipped()
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if self.viewModel.canTapNext {
                        self.viewModel.showNext()
                    } else {
                        //self.modalPresenterManager.dismiss()
                    }
                }
            VStack {
                HStack(spacing: 0) {
                    VStack {
                        WebImage(url: URL(string: self.viewModel.getStoryAvatarPath()))
                           .resizable()
                           .clipShape(Circle())
                           .frame(width: 52, height: 52)
                           .background(Circle().fill(Color.white).padding(-5))
                    }.tapGesture(toggls: $showsUserProfile)
                    
                    VStack(alignment: .leading) {
                        Text(self.viewModel.getStoryTitle()).font(.bold(24)).lineLimit(1)
                        Text(self.viewModel.getStoryTime()).font(.regular())
                    }
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
                    .padding(.leading, 20)
                    
                    Spacer()

                    HapticButton(action: { self.likedStory.toggle() }) {
                        Image("profile_heart")
                            .renderingMode(.template)
                            .foregroundColor(self.likedStory ? .red : .white)
                    }
                    
                    Button(action: {
                        if self.isNewStory {
                            self.modalPresenterManager.dismiss()
                        } else {
                            self.mode.wrappedValue.dismiss()
                        }
                    }) {
                        Image("close_icon").padding(20)
                    }
                    
                }.foregroundColor(.white)
                .padding(.leading, 20)
                
                HStack {
                    Spacer()
                    VStack {
                        ForEach(viewModel.stories.indices, id: \.self) { i in
                            Rectangle()
                                .foregroundColor(i <= self.viewModel.currentStoryIndex ? .hOrange : Color.white.opacity(0.5))
                                .frame(width: 5)
                                .frame(maxHeight: 84)
                        }
                        
                        Spacer()
                    }.padding(.trailing, 25)
                    .frame(height: proxy.size.height / 2)
                }
                
                Spacer()
                
                VStack {
                    if self.viewModel.isMyStory {
                        HStack {
                            Spacer()
                            Button(action: { self.showEdit.toggle() }) {
                                Image(systemName: "ellipsis")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .padding()
                            }.shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
                            .padding(.trailing)
                        }
                    }
                    
                    if viewModel.canSendMessages {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .foregroundColor(Color(0xF2F2F2).opacity(0.5))
                            
                            HStack {
                                TextField("", text: $viewModel.storyMessage)
                                    .font(.system(size: 17))
                                    .background(
                                        Text("Say something")
                                            .opacity(viewModel.storyMessage.isEmpty ? 1 : 0),
                                        alignment: .leading
                                    ).foregroundColor(Color.black.opacity(0.5))
                                Spacer()
                                Button(action: sendMessage) {
                                    Image("paperplane")
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                }.disabled(viewModel.storyMessage.isEmpty)
                            }.padding(.leading, 14)
                            .offset(x: 0, y: 2)
                        }.padding(.leading, 21)
                        .padding(.trailing, 16)
                        .frame(height: 40)
                        .padding(.bottom)
                        .offset(x: 0, y: -keyboardHeight)
                        .observeKeyboardHeight($keyboardHeight, withAnimation: .default)
                    }
                }
            }
            .background(
                NavigationLink(
                    destination: UserProfileView(viewModel: UserProfileViewModel(user: nil)).withoutBar(),
                    isActive: $showsUserProfile,
                    label: EmptyView.init
                )
            )
            
            HushIndicator(showing: self.viewModel.isShowingIndicator)
            
        }.actionSheet(isPresented: $showEdit) {
            ActionSheet(title: Text("Your Story"), message: nil, buttons: [
                .default(Text("Delete from story"), action: self.viewModel.deleteStory),
                .default(Text("Make Primary Image"), action: self.viewModel.makePrimaryImage),
                .cancel()
            ])
        }.gesture(dragToClose)
    }
    
    private func sendMessage() {
        viewModel.storyMessage = ""
        UIApplication.shared.endEditing()
    }
}

struct StoryView_Previews: PreviewProvider {
    static var previews: some View {
        StoryView(viewModel: StoryViewModel(stories: [], index: -1))
            .previewEnvironment()
            .hostModalPresenter()
            .edgesIgnoringSafeArea(.all)
    }
}
