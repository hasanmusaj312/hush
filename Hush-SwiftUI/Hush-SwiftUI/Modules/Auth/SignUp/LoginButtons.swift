//
//  LoginButtons.swift
//  Hush-SwiftUI
//
//  Created by Dima Virych on 30.03.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI
import FBSDKLoginKit

struct LoginButtons<Presenter: SignUpViewModeled>: View {
    
    @ObservedObject var fbmanager = UserLoginManager()
    @ObservedObject var presenter: Presenter
    @EnvironmentObject var app: App
    @State var name: String = ""
    @State var isLoggedIn: Bool = false
    @Binding var isShowingProgress: Bool
    
    var body: some View {
        VStack(spacing: 14) {
            LoginButton(title: "Sign Up with Email", img: Image("mail_icon"), color: Color(0x56CCF2)) {
                self.presenter.emailPressed()
            }.padding(.horizontal, 24)
            
            LoginButton(title: "Connect with Facebook", img: Image("facebook_icon"), color: Color(0x2672CB)) {
                
                self.fbmanager.facebookLogin(login_result: { fbResult in
                    let result: String = fbResult["result"] as! String
                    if result == "success" {
                        //self.app.logedIn = true
                        self.isShowingProgress = true

                        self.fbmanager.facebookConnect(data: fbResult) { result in
                            self.isShowingProgress = false

                            if result == true {
                                self.app.loadingData.toggle()
                                self.app.logedIn.toggle()
                            }
                        }
                    }
                })
            }.padding(.horizontal, 24)
            
            SignInWithAppleView(action: { login, name, email in
                
                if (login == true) {
                    self.isShowingProgress = true
                    
                    AuthAPI.shared.appleConnect(email: email, name: name) { (user, error) in
                        self.isShowingProgress = false

                        if error != nil {
                            
                        } else if let user = user {
                          
                            let isLoggedIn = UserDefault(.isLoggedIn, default: false)
                            isLoggedIn.wrappedValue = true
                            
                            Common.setUserInfo(user)
                            Common.setAddressInfo("Los Angels, CA, US")
                            let jsonData = try! JSONEncoder().encode(user)
                            let jsonString = String(data:jsonData, encoding: .utf8)!
                            
                            let currentUser = UserDefault(.currentUser, default: "")
                            currentUser.wrappedValue = jsonString
                            
                            self.app.loadingData.toggle()
                            self.app.logedIn.toggle()
                        }
                    }
                }
            }).frame(width: SCREEN_WIDTH - 48, height: 48)

//            LoginButton(title: "Sign in with Apple", titleColor: .black, img: Image("apple_icon"), color: Color(0xFFFFFF)) {
//                self.presenter.applePressed()
//            }.padding(.horizontal, 24)
        }
    }
}

struct LoginButton: View {
    
    let title: String
    var titleColor: Color = .white
    let img: Image
    let color: Color
    let action: () -> Void
    
    var body: some View {
        HapticButton(action: action) {
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(height: 48)
                    .cornerRadius(6)
                    .foregroundColor(color)
                HStack {
                    img
                        .resizable()
                        .foregroundColor(titleColor)
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                    Text(title)
                        .font(.medium(20))
                        .padding(.trailing, 20)
                        .minimumScaleFactor(0.7)
                    .lineLimit(1)
                        .foregroundColor(titleColor)
                }.padding(.leading, ISiPhone5 ? 20 : 50)
            }
        }
    }
}

struct LoginButtons_Previews: PreviewProvider {
    static var previews: some View {
        LoginButtons(presenter: SignUpViewModel(), isShowingProgress: .constant(false) )
    }
}
