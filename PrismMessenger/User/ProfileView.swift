//
//  ProfileView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI
import SwiftData
import CryptoKit

struct ProfileView: View {
    @EnvironmentObject private var appLaunch: AppLaunch
    @EnvironmentObject private var userService: UserService
    
    @State private var isEditingDisplayName = false
    @State private var newDisplayName = ""
    @State private var currentUser: User?
    @State private var showingAccountSelection = false
    @Query private var allUsers: [User]
    
    var body: some View {
        Group {
            if let user = currentUser {
                profileView(for: user)
        } else {
            LoadingView()
        }
        }
        .onAppear {
            loadCurrentUser()
        }
        .onChange(of: userService.selectedUsername) {
            loadCurrentUser()
        }
    }
    
    private func loadCurrentUser() {
        Task {
            currentUser = try? await userService.getCurrentUser()
        }
    }
    
    private func profileView(for user: User) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Button("Edit Profile") {
                        isEditingDisplayName = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }.padding(.horizontal)
                
                // Profile Image
                ProfileImageView(username: user.username)
                    .padding(.top)
                
                // Display Name, Username, and Public Key
                VStack(spacing: 4) {
                    if isEditingDisplayName {
                        VStack(spacing: 10) {
                            TextField("Display Name", text: $newDisplayName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal, 40)
                                .onAppear {
                                    newDisplayName = user.displayName ?? ""
                                }
                            
                            HStack {
                                Button("Cancel") {
                                    isEditingDisplayName = false
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Save") {
                                    user.displayName = newDisplayName.isEmpty ? nil : newDisplayName
                                    Task { try await userService.saveUser(user) }
                                    isEditingDisplayName = false
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 5)
                    } else {
                        if let displayName = user.displayName {
                            Text(displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Text("@\(user.username)")
                        .font(.title3)
                        .fontWeight(.medium)
                        .padding(.top, 1)
                    
                    Text(formatPublicKeyPreview(from: user))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 1)
                }
                
                Divider()
                    .padding(.vertical)
                
                // Account switcher button
                Button(action: {
                    showingAccountSelection = true
                }) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 18))
                        Text("Change Account")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.bottom)
            .sheet(isPresented: $showingAccountSelection) {
                accountSelectionView
            }
        }
    }
    
    // Account selection view shown in sheet
    private var accountSelectionView: some View {
        VStack(spacing: 20) {
            Text("Choose an Account")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            if allUsers.isEmpty {
                Text("No accounts found")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(allUsers) { user in
                            Button(action: {
                                userService.selectAccount(username: user.username)
                                showingAccountSelection = false
                            }) {
                                HStack {
                                    ProfileImageView(username: user.username, size: 40)
                                    
                                    VStack(alignment: .leading) {
                                        Text(user.displayName ?? user.username)
                                            .font(.headline)
                                        Text(user.username)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if user.username == userService.selectedUsername {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray6))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                }
            }
            
            Divider()
                .padding(.vertical)
            
            // Create new account button
            Button(action: {
                appLaunch.setUnregistered()
                showingAccountSelection = false
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Create New Account")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Button("Close") {
                showingAccountSelection = false
            }
            .padding(.top, 10)
        }
        .padding()
    }
    
    private func formatPublicKeyPreview(from user: User) -> String {
        do {
            let publicKey = try user.signedPrekey.toP256PrivateKey().publicKey
            let keyData = publicKey.rawRepresentation
            let keyString = keyData.base64EncodedString()
            
            // Show just the first 8 and last 8 characters with ... in between
            if keyString.count > 16 {
                let prefix = keyString.prefix(8)
                let suffix = keyString.suffix(8)
                return "\(prefix)...\(suffix)"
            }
            return keyString
        } catch {
            return "Error loading key"
        }
    }
}

struct ProfileImageView: View {
    let username: String
    var size: CGFloat = 150
    
    var body: some View {
        ZStack {
            Circle()
                .fill(generateColor(from: username))
                .frame(width: size, height: size)
            
            Text(String(username.first ?? Character("?")))
                .font(.system(size: size * 0.4))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
    
    private func generateColor(from string: String) -> Color {
        let hash = string.utf8.reduce(0) { $0 + Int($1) }
        
        // Generate consistent but diverse hues based on hash
        let hue = Double(hash % 360) / 360.0
        
        // Use medium-high saturation and brightness for vibrant but not harsh colors
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: User.self, configurations: config)
    let modelContext = ModelContext(container)
    
    let user = User(
        signedPrekey: P256.Signing.PrivateKey(),
        username: "alice_prism",
        displayName: "Alice Wonderland"
    )
//    modelContext.insert(user)
//    let userService = UserService(userRepository: SwiftDataUserRepository(modelContext: modelContext))
//    userService.selectAccount(username: "alice_prism")
//    let appLaunch = AppLaunch()
//    appLaunch.setRegistered()
    ProfileView()
//        .environmentObject(appLaunch)
//        .environmentObject(userService)
}
