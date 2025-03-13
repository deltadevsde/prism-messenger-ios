//
//  ChatsView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import SwiftData
import SwiftUI

struct ChatsView: View {
    @EnvironmentObject private var chatManager: ChatManager
    @EnvironmentObject private var userService: UserService
    
    @State private var showingNewChatSheet = false
    @State private var currentChats: [Chat] = []
    @State private var refreshTrigger = false  // Refresh trigger for manual refreshes
    
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
            .sheet(
                isPresented: $showingNewChatSheet,
                onDismiss: {
                    // Refresh the chats list when the sheet is dismissed
                    refreshTrigger.toggle()
                }
            ) {
                NewChatView()
            }
            .onAppear {
                loadChats()
            }
            .onChange(of: userService.selectedUsername) {
                loadChats()
            }
            .onChange(of: refreshTrigger) {
                loadChats()
            }
            .refreshable {
                loadChats()
            }
        }
    }
    
    private func loadChats() {
        Task {
            let userChats = (try? await chatManager.getAllChats()) ?? []
            
            DispatchQueue.main.async {
                self.currentChats = userChats
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

    init(
        username: String, imageURL: String? = nil, message: String, lastMessageTime: Date? = nil,
        unreadCount: Int = 0
    ) {
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
    @EnvironmentObject private var chatManager: ChatManager

    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdChat: Chat?
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
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
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
                let chat = try await chatManager.startChat(with: username)

                print("Successfully created chat with \(username)")

                // Store the created chat and navigate to it
                DispatchQueue.main.async {
                    createdChat = chat
                    shouldNavigateToChat = true
                    isLoading = false
                    dismiss()
                }
            } catch ChatManagerError.missingKeyBundle {
                DispatchQueue.main.async {
                    errorMessage = "No key bundle found for \(username)"
                    isLoading = false
                }
            } catch ChatManagerError.missingPreKeys {
                DispatchQueue.main.async {
                    errorMessage = "No pre keys found for \(username)"
                    isLoading = false
                }
            } catch ChatManagerError.otherUserNotFound {
                DispatchQueue.main.async {
                    errorMessage = "User not found. Please check the username."
                    isLoading = false
                }
            } catch ChatManagerError.keyExchangeFailed {
                DispatchQueue.main.async {
                    errorMessage = "Key exchange failed"
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
    let container = try! ModelContainer(
        for: User.self, Chat.self, MessageData.self, configurations: config)
    let context = ModelContext(container)

    // Create sample data for the preview
    let chat1 = Chat(
        participantUsername: "johndoe",
        ownerUsername: "alice",
        displayName: "John Doe",
        doubleRatchetSession: Data()
    )
    let message1 = MessageData(content: "Hello there!", isFromMe: false)
    message1.chat = chat1
    chat1.addMessage(message1)

    let chat2 = Chat(
        participantUsername: "sarahsmith",
        ownerUsername: "alice",
        displayName: "Sarah Smith",
        doubleRatchetSession: Data()
    )
    let message2 = MessageData(content: "Can't wait to see you tomorrow!", isFromMe: true)
    message2.chat = chat2
    chat2.addMessage(message2)

    context.insert(chat1)
    context.insert(chat2)
    
    let appContext = AppContext(modelContext: context)
    appContext.userService.selectAccount(username: "alice")

    return ChatsView()
        .environmentObject(appContext.chatManager)
        .environmentObject(appContext.userService)
}
