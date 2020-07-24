//
//  MessageDetailView.swift
//  Hush-SwiftUI
//
//  Created Dima Virych on 06.04.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI
import SDWebImageSwiftUI

struct MessageDetailView<ViewModel: MessageDetailViewModeled>: View, HeaderedScreen {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: ViewModel
    @Environment(\.presentationMode) var mode
    @EnvironmentObject var app: App
    @State private var keyboardHeight: CGFloat = 0
    
    // MARK: - Lifecycle
    
    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 0) {
                Text($viewModel.peerName.wrappedValue).font(.thin(48)).foregroundColor(.hOrange)
                HStack(alignment: .top) {
                    HapticButton(action: { self.mode.wrappedValue.dismiss() }) {
                        HStack(spacing: 23) {
                            Image("onBack_icon")
                            Text("Back to messages").foregroundColor(.white).font(.thin())
                        }
                    }
                    Spacer()
                    WebImage(url: URL(string: $viewModel.peerImagePath.wrappedValue))
                    .resizable()
                    .placeholder {
                        Image("placeholder_s").frame(width: 60, height: 60, alignment: .center)
                    }
                    .background(Color.white)
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(30)
                    .overlay(Circle()
                        .fill(Color(0x27AE60))
                        .square(22)
                        .padding(.trailing, 0),
                         alignment: .topTrailing)
                    
//                    Image("story3")
//                        .aspectRatio()
//                        .frame(width: 60, height: 60)
//                        .cornerRadius(30)
//                        .padding(.trailing, 20)
//                        .overlay(Circle()
//                            .fill(Color(0x27AE60))
//                            .square(22)
//                            .padding(.trailing, 9),
//                        alignment: .topTrailing)
                }
            }.padding([.horizontal])
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(self.viewModel.messages(), id: \.id) { message in
                        self.viewForMessage(message)
                    }
                }.padding(.bottom, 30)
            }
            .rotationEffect(.degrees(180))
            
            SendTextField(placeholder: "Type your Message", onsend: viewModel.sendMessage(_:), onimage: viewModel.sendImage(_:))
                .padding(.horizontal, 15)

            Spacer(minLength: keyboardHeight - 70)
        }
        .observeKeyboardHeight($keyboardHeight, withAnimation: .default)
        .background(Color.hBlack.edgesIgnoringSafeArea(.all))
    }
    
    private func viewForMessage(_ message: HushMessage) -> some View {
        Group {
            if message.isText {
                viewForTextMessage(message)
            }
            
            if message.isImage {
                viewForImageMessage(message)
            }
        }
    }
    
    private func viewForTextMessage(_ message: HushMessage) -> some View {
        guard case let .text(textMessage) = message else { fatalError() }
        return ContentTextMessageView(
            time: message.time,
            contentMessage: textMessage.text,
            isCurrentUser: message.userID == "SELF",
            shouldShowDate: self.messageShouldShowDate(message)
        ).rotationEffect(.degrees(180))
        .padding(message.userID == "SELF" ? .trailing : .leading, 70)
        
    }
    
    private func viewForImageMessage(_ message: HushMessage) -> some View {
        guard case let .image(imageMessage) = message else { fatalError() }
        return ContentImageMessageView(image: imageMessage.image, time: message.createdAt, isCurrentUser: true, shouldShowDate: self.messageShouldShowDate(message))
            .rotationEffect(.degrees(180))
            .padding(message.userID == "SELF" ? .trailing : .leading, 70)
        
    }
    
    func messageShouldShowDate(_ message: HushMessage) -> Bool {
        let messages = viewModel.messages()
        guard let index = messages.firstIndex(of: message), index > 0 else { return true }
        return messages[index - 1].userID != message.userID
    }
}

struct MessageDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                MessageDetailView(viewModel: MessageDetailViewModel(MessagesViewModel().item(at: 3), imagePath: "https://www.hushdating.app/assets/sources/uploads/thumb_5efdff0a0e620_image1.jpg")).withoutBar()
            }
        }
    }
}
