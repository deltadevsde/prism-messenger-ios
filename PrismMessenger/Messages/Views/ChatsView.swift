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
    @EnvironmentObject private var chatService: ChatService
    @EnvironmentObject private var userService: UserService
    @EnvironmentObject private var router: NavigationRouter

    @State private var showingNewChatSheet = false
    @State private var currentChats: [Chat] = []
    @State private var refreshTrigger = false  // Refresh trigger for manual refreshes

    @State private var chatsQuery = ""

    private var filteredChats: [Chat] {
        guard !chatsQuery.isEmpty else { return currentChats }
        return currentChats.filter {
            ($0.displayName ?? $0.participantId.uuidString).lowercased()
                .contains(chatsQuery.lowercased())
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading) {
                searchBar

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
                            ForEach(filteredChats) { chat in
                                Button(action: {
                                    router.navigateTo(Route.chat(chat))
                                }) {
                                    ChatPreview(
                                        username: chat.displayName ?? chat.participantId.uuidString,
                                        imageURL: chat.imageURL,
                                        message: chat.lastMessage ?? "No messages yet",
                                        lastMessageTime: chat.lastMessageTimestamp,
                                        unreadCount: chat.unreadCount
                                    )
                                    .contentShape(Rectangle())
                                }
                            }
                        }
                    }.padding(.horizontal, 20)
                }
            }

            Button(action: {
                showingNewChatSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Start Chat")
                }
                .padding(10)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()  // This adds padding from the edge
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
        .onChange(of: refreshTrigger) {
            loadChats()
        }
        .refreshable {
            loadChats()
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search", text: $chatsQuery)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func loadChats() {
        Task {
            let userChats = (try? await chatService.getAllChats()) ?? []

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
        username: String,
        imageURL: String? = nil,
        message: String,
        lastMessageTime: Date? = nil,
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
    @EnvironmentObject private var chatService: ChatService
    @EnvironmentObject private var router: NavigationRouter

    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

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
        }
    }

    private func startChat() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let chat = try await chatService.startChat(with:username)
                print("Successfully created chat with \(username)")

                DispatchQueue.main.async {
                    isLoading = false
                    dismiss()
                    router.navigateTo(.chat(chat))
                }
            } catch ChatServiceError.missingKeyBundle {
                DispatchQueue.main.async {
                    errorMessage = "No key bundle found for \(username)"
                    isLoading = false
                }
            } catch ChatServiceError.missingPreKeys {
                DispatchQueue.main.async {
                    errorMessage = "No pre keys found for \(username)"
                    isLoading = false
                }
            } catch ChatServiceError.otherUserNotFound {
                DispatchQueue.main.async {
                    errorMessage = "User not found. Please check the username."
                    isLoading = false
                }
            } catch ChatServiceError.keyExchangeFailed {
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
    AsyncPreview {
        ChatsView()
    } withSetup: { context in
        let chatService = context.chatService
        let registrationService = context.registrationService

        try! await registrationService.registerNewUser(username: "Bob")
        try! await registrationService.registerNewUser(username: "Charlie")
        try! await registrationService.registerNewUser(username: "Alice")

        let chat1 = try! await chatService.startChat(with: "Bob")
        try! await chatService.sendMessage(content: "Test", in: chat1)

        let chat2 = try! await chatService.startChat(with: "Charlie")
        try! await chatService.sendMessage(content: "Hello", in: chat2)
    }
}
