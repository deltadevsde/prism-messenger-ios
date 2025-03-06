//
//  ChatsView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI
import SwiftData
import CryptoKit

struct ChatsView: View {
    @State private var showingNewChatSheet = false
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var appLaunch: AppLaunch
    @State private var currentChats: [ChatData] = []
    @Environment(\.modelContext) private var modelContext
    @State private var refreshTrigger = false // Refresh trigger for manual refreshes
    
    var body: some View {
        NavigationStack {
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
                    if currentChats.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "message.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No chats yet")
                                .font(.headline)
                            Text("Start a new conversation by tapping the pencil icon")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                    } else {
                        ForEach(currentChats) { chat in
                            NavigationLink(destination: {
                                // Using a closure form that creates a new binding for each chat
                                let bindableChat = chat
                                ChatView(chat: bindableChat)
                            }) {
                                ChatPreview(
                                    username: chat.displayName ?? chat.participantUsername,
                                    imageURL: chat.imageURL,
                                    message: chat.lastMessage ?? "No messages yet",
                                    lastMessageTime: chat.lastMessageTimestamp,
                                    unreadCount: chat.unreadCount
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }.padding(.horizontal)
                Divider()
            }
        }
        .sheet(isPresented: $showingNewChatSheet, onDismiss: {
            // Refresh the chats list when the sheet is dismissed
            refreshTrigger.toggle()
        }) {
            NewChatView()
        }
        .onAppear {
            loadChats()
        }
        .onChange(of: refreshTrigger) { _ in
            loadChats()
        }
        .refreshable {
            loadChats()
        }
        }
    }
    
    private func loadChats() {
        Task {
            do {
                // Get the current username from the UserManager
                let username: String
                do {
                    username = try await MainActor.run { try appContext.userManager.getCurrentUsername() }
                } catch {
                    DispatchQueue.main.async {
                        self.currentChats = []
                    }
                    return
                }
                
                // Get chats that have the current user as the owner
                let descriptor = FetchDescriptor<ChatData>(
                    predicate: #Predicate<ChatData> { chat in
                        chat.ownerUsername == username
                    },
                    sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
                )
                
                let userChats = try modelContext.fetch(descriptor)
                
                DispatchQueue.main.async {
                    self.currentChats = userChats
                }
            } catch {
                DispatchQueue.main.async {
                    self.currentChats = []
                }
            }
        }
    }
}

struct ChatPreview: View {
    private let username: String
    private let imageURL: String?
    private let message: String
    private let lastMessageTime: Date?
    private let unreadCount: Int
    
    init(username: String, imageURL: String? = nil, message: String, lastMessageTime: Date? = nil, unreadCount: Int = 0) {
        self.username = username
        self.imageURL = imageURL
        self.message = message
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let imageURL = imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(username)
                    .font(.system(size: 16, weight: .semibold))
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let time = lastMessageTime {
                    Text(timeString(from: time))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            return formatter.string(from: date)
        }
    }
}

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContext: AppContext
    
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdChat: ChatData?
    @State private var shouldNavigateToChat = false
    
    var body: some View {
        NavigationStack {
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
            .navigationDestination(isPresented: $shouldNavigateToChat) {
                if let chat = createdChat {
                    let bindableChat = chat
                    ChatView(chat: bindableChat)
                }
            }
        }
    }
    
    private func startChat() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Check if a chat with this user already exists
                if let existingChat = try appContext.chatManager.getChat(with: username) {
                    print("Chat with \(username) already exists, navigating to it")
                    
                    DispatchQueue.main.async {
                        createdChat = existingChat
                        shouldNavigateToChat = true
                        isLoading = false
                        dismiss()
                    }
                    return
                }
                
                // 1. Try to get the key bundle
                let keyBundle: KeyBundle
                do {
                    keyBundle = try await appContext.keyService.getKeyBundle(username: username)
                } catch KeyError.userNotFound {
                    DispatchQueue.main.async {
                        errorMessage = "User does not exist"
                        isLoading = false
                    }
                    return
                } catch {
                    DispatchQueue.main.async {
                        errorMessage = "Failed to fetch key bundle: \(error.localizedDescription)"
                        isLoading = false
                    }
                    return
                }
                
                guard let prekey = keyBundle.prekeys.first else {
                    DispatchQueue.main.async {
                        errorMessage = "User is missing prekeys"
                        isLoading = false
                    }
                    return
                }

                // 2. Initialize X3DH with our key manager
                let x3dh = try appContext.createX3DHSession()

                // 3. Perform the X3DH handshake
                let (sharedSecret, ephemeralPrivateKey, usedPrekeyId) = try await x3dh.initiateHandshake(with: keyBundle, using: prekey.key_idx)

                print("Successfully performed X3DH handshake with user: \(username)")
                print("Used prekey ID: \(String(describing: usedPrekeyId))")
                
                // 4. Create a new chat with the Double Ratchet session
                let chat = try appContext.chatManager.createChat(
                    username: username,
                    sharedSecret: sharedSecret,
                    ephemeralPrivateKey: ephemeralPrivateKey,
                    prekey: prekey
                )
                
                print("Successfully created chat with \(username)")
                
                // Store the created chat and navigate to it
                DispatchQueue.main.async {
                    createdChat = chat
                    shouldNavigateToChat = true
                    isLoading = false
                    dismiss()
                }
            } catch KeyError.userNotFound {
                DispatchQueue.main.async {
                    errorMessage = "User not found. Please check the username."
                    isLoading = false
                }
            } catch X3DHError.keyConversionFailed {
                DispatchQueue.main.async {
                    errorMessage = "Key conversion failed"
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

// Preview removed temporarily for testing
