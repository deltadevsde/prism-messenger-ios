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
    @Query private var chats: [ChatData]
    
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
                    if chats.isEmpty {
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
                        ForEach(chats) { chat in
                            ChatPreview(
                                username: chat.displayName ?? chat.participantUsername,
                                imageURL: chat.imageURL,
                                message: chat.lastMessage ?? "No messages yet",
                                lastMessageTime: chat.lastMessageTimestamp,
                                unreadCount: chat.unreadCount
                            )
                        }
                    }
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
                // Check if a chat with this user already exists
                if let existingChat = try appContext.chatManager.getChat(with: username) {
                    print("Chat with \(username) already exists, navigating to it")
                    // TODO: Navigate to the existing chat instead of creating a new one
                    DispatchQueue.main.async {
                        isLoading = false
                        dismiss()
                    }
                    return
                }
                
                // 1. Try to get the key bundle
                let keyBundle = try await appContext.keyService.getKeyBundle(username: username)
                
                if keyBundle == nil {
                    DispatchQueue.main.async {
                        errorMessage = "User does not exist"
                        isLoading = false
                    }
                    return
                }

                // 2. Initialize X3DH with our key manager
                let x3dh = try appContext.createX3DHSession()

                // 3. Perform the X3DH handshake
                let (sharedSecret, ephemeralPublicKey, usedPrekeyId) = try await x3dh.initiateHandshake(with: keyBundle!)

                print("Successfully performed X3DH handshake with user: \(username)")
                print("Used prekey ID: \(String(describing: usedPrekeyId))")
                
                // 4. Create a new chat with the Double Ratchet session
                let chat = try appContext.chatManager.createChat(
                    username: username,
                    sharedSecret: sharedSecret,
                    ephemeralPublicKey: ephemeralPublicKey,
                    usedPrekeyId: usedPrekeyId
                )
                
                print("Successfully created chat with \(username)")
                
                // Close the sheet
                DispatchQueue.main.async {
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserData.self, ChatData.self, MessageData.self, configurations: config)
    let context = ModelContext(container)
    
    // Create sample data for the preview
    let chatData = ChatData(participantUsername: "sample_user", displayName: "Sample User", doubleRatchetSession: Data())
    let message = MessageData(content: "Hello there!", isFromMe: false)
    message.chat = chatData
    chatData.addMessage(message)
    
    context.insert(chatData)
    
    return ChatsView()
        .modelContainer(container)
        .environmentObject(try! AppContext(modelContext: context))
}
