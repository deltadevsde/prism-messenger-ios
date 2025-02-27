//
//  AccountSelectionView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI
import SwiftData

struct AccountSelectionView: View {
    @EnvironmentObject var appLaunch: AppLaunch
    @Query private var users: [UserData]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choose an Account")
                .font(.largeTitle)
                .bold()
                .padding(.bottom)
            
            if users.isEmpty {
                Text("No accounts found")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(users) { user in
                            Button(action: {
                                appLaunch.selectAccount(username: user.username)
                            }) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading) {
                                        Text(user.displayName ?? user.username)
                                            .font(.headline)
                                        Text(user.username)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                appLaunch.createNewAccount()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create New Account")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserData.self, configurations: config)
    let context = ModelContext(container)
    
    // Create some sample users for preview
    let user1 = UserData(signedPrekey: P256.Signing.PrivateKey(), username: "alice", displayName: "Alice")
    let user2 = UserData(signedPrekey: P256.Signing.PrivateKey(), username: "bob", displayName: "Bob")
    context.insert(user1)
    context.insert(user2)
    try! context.save()
    
    return AccountSelectionView()
        .environmentObject(AppLaunch())
        .modelContainer(container)
}