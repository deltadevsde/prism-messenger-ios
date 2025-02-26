//
//  ChatsView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI
import CryptoKit

struct ChatsView: View {
    @State private var showingNewChatSheet = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Messages")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                    showingNewChatSheet = true
                }) {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(Color.blue)
                }
            }.padding(.horizontal)
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    ChatPreview(
                        username: "Sebastian Pusch",
                        imageURL: "https://pbs.twimg.com/profile_images/1836079646229614596/pL5ylf4__400x400.jpg",
                        message: "Hey Ryan"
                    )
                }.padding(.horizontal)
                Divider()
            }
        }
        .sheet(isPresented: $showingNewChatSheet) {
            NewChatView()
        }
    }
}

struct ChatPreview: View {
    private let username: String
    private let imageURL: String
    private let message: String
    
    init(username: String, imageURL: String, message: String) {
        self.username = username
        self.imageURL = imageURL
        self.message = message
    }
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(username)
                    .font(.system(size: 16, weight: .semibold))
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContext: AppContext
    
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Start a New Chat")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Username input field
                TextField("Enter username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal)
                
                // Error message if any
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // Start chat button
                Button("Start Chat") {
                    startChat()
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || isLoading)
                
                if isLoading {
                    ProgressView()
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
    
    private func startChat() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Try to get the key bundle
                let keyBundle = try await appContext.keyService.getKeyBundle(username: username)
                
                // 2. Initialize X3DH with our key manager
                let x3dh = try appContext.createX3DHSession()
                
                // 3. Perform the X3DH handshake
                let (sharedSecret, ephemeralPublicKey, usedPrekeyId) = try await x3dh.initiateHandshake(with: keyBundle)
                
                print("Successfully performed X3DH handshake with user: \(username)")
                print("Used prekey ID: \(String(describing: usedPrekeyId))")
                
                // TODO: Store this session for future encrypted communication
                // We would typically:
                // 1. Initialize a Double Ratchet session with the shared secret
                // 2. Store the session in a local database
                // 3. Send an initial message to the recipient with our ephemeral key
                
                // For now, just close the sheet
                DispatchQueue.main.async {
                    isLoading = false
                    dismiss()
                }
            } catch KeyError.userNotFound {
                DispatchQueue.main.async {
                    errorMessage = "User not found. Please check the username."
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Failed to connect: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ChatsView()
        .environmentObject(try! AppContext())
}
