//
//  SignUpView.swift
//  Hush-SwiftUI
//
//  Created by Dima Virych on 30.03.2020.
//  Copyright © 2020 AppServices. All rights reserved.
//

import SwiftUI

struct SignUpView<ViewModel: SignUpViewModeled>: View, AuthAppScreens {
    
    @State var showSignupButtons = false
    
    @ObservedObject var viewModel: ViewModel
    @EnvironmentObject var app: App
    @State var isShowing: Bool = false

    var body: some View {
        
        ZStack {
            VStack {
                logo()
                    .opacity(showSignupButtons ? 0.3 : 1)
                    .padding(.top, showSignupButtons ? -100 : 55)
                Spacer()
            }
            VStack {
                Spacer()
                signupButton()
                    .padding(.bottom, showSignupButtons ? 140 : 220)
            }
            
            VStack(spacing: 28) {
                
                Spacer()
                
                HapticButton(action: viewModel.login, label: {
                    Text("Already have an account? Log In")
                        .font(.medium(16))
                        .foregroundColor(.white)
                })
                
                bottomText()
            }.padding(.bottom, 20)
            
            NavigationLink(destination: SignUpEmail(viewModel: SignUpEmailViewModel()), isActive: $viewModel.showEmailScreen, label: EmptyView.init)
            NavigationLink(destination: LoginView(viewModel: LoginViewModel()), isActive: $viewModel.showLoginScreen, label: EmptyView.init)
            
            HushIndicator(showing: self.isShowing)
            
        }.background(background())
    }
}


// MARK: - Signup button

extension SignUpView {
    
    func signupButton() -> some View {
        
        VStack(spacing: 17) {
            HapticButton(action: { withAnimation {
                self.showSignupButtons.toggle()
                self.app.showSignupButtons = self.showSignupButtons
                } }) {
                
                if !showSignupButtons {
                    Image("arrowUp_icon").resizable().aspectRatio(contentMode: .fit).frame(width: 18, height: 18)
                }
                Text("Sign Up")
                    .foregroundColor(.white)
                    .font(.medium(24))
                if showSignupButtons {
                    Image("arrowDown_icon").resizable().aspectRatio(contentMode: .fit).frame(width: 18, height: 18)
                }
            }.opacity(showSignupButtons ? 0.5 : 1)
            
            if showSignupButtons {
                LoginButtons(presenter: viewModel, isShowingProgress: self.$isShowing).transition(buttonsTransition())
            }
        }.frame(maxWidth: .infinity)
    }
    
    private func buttonsTransition() -> AnyTransition {
        AnyTransition.move(edge: .bottom).combined(with: .opacity)
    }
}


// MARK: - Bottom text

extension SignUpView {
    
    private func bottomText() -> some View {
        VStack(spacing: 0) {
            Text("We don't post anything on Facebook.\n By registering and using Hush you agree to")
            HStack(spacing: 0) {
                Text(" our ")
                terms()
                Text(" and ")
                policy()
            }
        }
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .font(.regular(12))
        .opacity(0.8)
    }
    
    private func terms() -> some View {
        
        Text("Terms & Conditions").underline().onTapGesture(perform: viewModel.terms)
    }
    
    private func policy() -> some View {
        
        Text("Privacy Policy.").underline().onTapGesture(perform: viewModel.privacy)
    }
}


// MARK: - Previews

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(viewModel: SignUpViewModel())
    }
}
