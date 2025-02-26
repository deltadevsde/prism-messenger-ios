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
    @Query var users: [UserData]
    @Environment(\.modelContext) private var modelContext
    @State private var isEditingDisplayName = false
    @State private var newDisplayName = ""
    
    var body: some View {
        if let user = users.first {
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
                                        try? modelContext.save()
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
                    
                    Spacer()
                }
                .padding(.bottom)
            }
        } else {
            LoadingView()
        }
    }
    
    private func formatPublicKeyPreview(from user: UserData) -> String {
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
    ProfileView().modelContainer(DataController.previewContainer)
}

@MainActor
class DataController {
    static let previewContainer: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: UserData.self, configurations: config)

            let user = UserData(
                signedPrekey: P256.Signing.PrivateKey(), 
                username: "alice_prism", 
                displayName: "Alice Wonderland"
            )
            container.mainContext.insert(user)

            return container
        } catch {
            fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
        }
    }()
}
