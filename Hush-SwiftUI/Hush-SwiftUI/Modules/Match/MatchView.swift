//
//  MatchView.swift
//  Hush-SwiftUI
//
//  Created Maksym on 06.08.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI
import QGrid
import PartialSheet
import Purchases
struct MatchView<ViewModel: MatchViewModeled>: View {
    
    // MARK: - Properties
    @EnvironmentObject private var app: App
    @ObservedObject var viewModel: ViewModel
    let title: String
    let match_type: String
    let blured: Bool
    
    @State private var showsUserProfile = false
    @State private var showUpgrade = false
    @Environment(\.presentationMode) var mode
    @State var selectedUser: User = User()

    init(viewModel: ViewModel, title: String, match_type: String, blured: Bool) {
        self.viewModel = viewModel
        self.title = title
        self.match_type = match_type
        self.blured = blured
        
        if (match_type == "matches") {
            self.viewModel.loadMatches { (result) in
            }
        }
        else if (match_type == "visited_me") {
            self.viewModel.loadVisitedMe { (result) in
            }
        }
        else if (match_type == "my_likes") {
            self.viewModel.loadMyLikes { (result) in
            }
        }
        else if (match_type == "likes_me") {
            self.viewModel.loadLikesMe { (result) in
            }
        }
    }

    // MARK: - Lifecycle
    
    var body: some View {
        ZStack {
            VStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.thin(48)).foregroundColor(.hOrange).padding(.top, ISiPhoneX ? 0 : 0).padding(.leading, 10)
                    HStack(alignment: .top) {
                       HapticButton(action: { self.mode.wrappedValue.dismiss() }) {
                           HStack(spacing: 23) {
                               Image("onBack_icon")
                               Text("Back to My Profile").foregroundColor(.white).font(.thin())
                           }
                       }.padding(.leading, 10)
                       Spacer()
                    }
                }.padding([.horizontal])
                   
                if self.viewModel.matches.count > 0 {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: -20) {
                            ForEach(0...(viewModel.matches.count / 2), id: \.self) {
                                self.row(at: $0)
                            }
                        }.padding(.top, 10)
                    }
                    .background(
                        NavigationLink(
                            destination: UserProfileView(viewModel: UserProfileViewModel(user: selectedUser)),
                            isActive: $showsUserProfile,
                            label: EmptyView.init
                        )
                    )
                    .background(
                        NavigationLink(
                            destination: UpgradeView(viewModel: UpgradeViewModel()).withoutBar().onDisappear(perform: {
                                if (Common.premium()) {
                                    self.showsUserProfile.toggle()
                                }
                            }),
                            isActive: $showUpgrade,
                            label: EmptyView.init
                        )
                        
                    )
                } else {
                    Spacer()
                }
            }
            
            HushIndicator(showing: self.viewModel.isShowingIndicator)

        }.background(Color.hBlack.edgesIgnoringSafeArea(.all))
    }
     
    func row(at i: Int) -> some View {
        HStack(spacing: -18) {
            ForEach(0..<2, id: \.self) { j in
                HStack {
                    if (i * 2 + j < self.viewModel.matches.count) {
                        self.polaroidCard(i, j)
                        
                    } else {
                        Spacer()
                    }
                }
            }
        }.zIndex(Double(100 - i))
    }
    
    func polaroidCard(_ i: Int, _ j: Int) -> some View {
        
        PhotoCard(image: self.viewModel.matches[i*2+j].photo!, cardWidth: SCREEN_WIDTH / 2 + 15, bottom: self.bottomView(i, j), blured: self.blured)
        .offset(x: j % 2 == 0 ? -10 : 10, y: 0)
        .zIndex(Double(i % 2 == 0 ? j : -j))
        .rotationEffect(.degrees(self.isRotated(i, j) ? 0 : -5), anchor: UnitPoint(x: 0.5, y: i % 2 == 1 ? 0.4 : 0.75))
        .onTapGesture {
            if (self.blured) {
                if (Common.premium()) {
                    self.showsUserProfile = true
                } else {
                    self.viewModel.isShowingIndicator = true

                    Purchases.shared.purchaserInfo { (purchaserInfo, error) in
                        self.viewModel.isShowingIndicator = false
                        if purchaserInfo?.entitlements["pro"]?.isActive == true {
                            Common.setPremium(true)
                            self.showsUserProfile.toggle()
                        } else {
                            Common.setPremiumType(isUser: true)
                            self.app.showPremium.toggle()
                        }
                    }
                }
            } else {
                let match = self.viewModel.matches[i * 2 + j]
                self.viewModel.isShowingIndicator = true
                
                AuthAPI.shared.get_user_data(userId: match.id ?? "1") { (user, error) in
                    self.viewModel.isShowingIndicator = false
                    if (error == nil) {
                        if let user = user {
                            self.selectedUser = user
                            self.showsUserProfile.toggle()
                        }
                    }
                }
            }
        }
    }
    
    func leading(_ j: Int) -> CGFloat {
        j % 2 == 0 ? 25 : 0
    }
    
    func trailing(_ j: Int) -> CGFloat {
        j % 2 == 0 ? 0 : 23
    }
    
    func isRotated(_ i: Int, _ j: Int) -> Bool {
        let index = i * 2 + j
        return index % 4 == 0 || stride(from: 3, through: index, by: 4).contains(index)
    }
    
    func bottomView(_ i: Int, _ j: Int) -> some View {
        let match = viewModel.match(i, j)
        return HStack {
            (Text(match.name ?? "John") + Text(", ") + Text("\(match.age ?? "20")"))
                .font(.regular(14))
                .blur(radius: blured ? 2 : 0)
                .foregroundColor(Color(0x8E8786))
            Spacer()
            Button(action: { self.viewModel.like(i, j) }) {
                Image("red_heart")
                    .resizable()
                    .renderingMode(match.liked! ? .original : .template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
                    .foregroundColor(.gray)
            }
        }.padding(15)
        .padding(.leading, self.leading(j))
        .padding(.trailing, self.trailing(j))
    }
    
    
}

struct MatchesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MatchView(viewModel: MatchViewModel(), title: "Matches", match_type: "image1", blured: true)
        }
    }
}
