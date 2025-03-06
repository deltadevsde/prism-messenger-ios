//
//  ChatView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Bindable var chat: ChatData
    @State private var messageText: String = ""
    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    @FocusState private var isTextFieldFocused: Bool
    @EnvironmentObject private var appContext: AppContext
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            headerView
            
            // Messages list
            messagesList
            
            // Error message display
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
            
            // Input area
            inputView
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Mark chat as read when view appears
            chat.markAsRead()
        }
        .refreshable {
            // Force refresh when user pulls down
            Task {
                try? await appContext.messageCoordinator.fetchAndProcessMessages()
            }
        }
        // Periodically refresh messages when view is active
        .task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    try? await appContext.messageCoordinator.fetchAndProcessMessages()
                } catch {
                    break
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            // Profile image
            if let imageURL = chat.imageURL, let url = URL(string: imageURL) {
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
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.displayName ?? chat.participantUsername)
                    .font(.headline)
                
                Text("Online") // This would be dynamic in a real implementation
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
    }
    
    private var messagesList: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chat.messages.sorted(by: { $0.timestamp < $1.timestamp })) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 10)
            }
            .onChange(of: chat.messages.count) { _, _ in
                if let lastMessage = chat.messages.sorted(by: { $0.timestamp < $1.timestamp }).last {
                    withAnimation {
                        scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastMessage = chat.messages.sorted(by: { $0.timestamp < $1.timestamp }).last {
                    scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    private var inputView: some View {
        HStack(spacing: 12) {
            // Attachment button (placeholder for future functionality)
            Button {
                // Add attachment functionality here
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
            }
            
            // Text field
            ZStack(alignment: .trailing) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .focused($isTextFieldFocused)
                    .lineLimit(5)
                    .disabled(isLoading)
                
                if isLoading {
                    ProgressView()
                        .padding(.trailing, 10)
                }
            }
            
            // Send button
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        isLoading = true
        error = nil
        
        // Clear the text field immediately for a better user experience
        let messageToSend = trimmedMessage
        messageText = ""
        
        Task {
            do {
                // Send the message using the MessageService
                _ = try await appContext.chatManager.sendMessage(
                    content: messageToSend, 
                    in: chat,
                    messageService: appContext.messageService
                )
                
                DispatchQueue.main.async {
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = "Failed to send message: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: MessageData
    
    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    HStack(spacing: 4) {
                        Text(formattedTime)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        // Status indicators
                        statusIcon
                    }
                    .padding(.trailing, 4)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    Text(formattedTime)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                Spacer()
            }
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: message.timestamp)
    }
    
    private var statusIcon: some View {
        Group {
            switch message.status {
            case .sending:
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            case .delivered:
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            case .read:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
        }
    }
}

struct ChatViewPreview: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: UserData.self, ChatData.self, MessageData.self, configurations: config)
        let context = ModelContext(container)
        
        // Create data preparation function
        func prepareData() -> (ChatData, AppContext) {
            // Create sample data for the preview
            let chatData = ChatData(
                participantUsername: "johndoe", 
                ownerUsername: "alice", 
                displayName: "John Doe", 
                doubleRatchetSession: Data()
            )
            
            // Add a few sample messages
            let message1 = MessageData(content: "Hey there! How's it going?", isFromMe: false)
            message1.chat = chatData
            chatData.addMessage(message1)
            
            let message2 = MessageData(content: "Not bad! Just working on this app. How about you?", isFromMe: true)
            message2.chat = chatData
            chatData.addMessage(message2)
            
            let message3 = MessageData(content: "That's cool! I've been exploring some new hiking trails nearby.", isFromMe: false)
            message3.chat = chatData
            chatData.addMessage(message3)
            
            let message4 = MessageData(content: "That sounds awesome! Which trails did you check out?", isFromMe: true, status: .delivered)
            message4.chat = chatData
            chatData.addMessage(message4)
            
            context.insert(chatData)
            
            let appContext = try! AppContext(modelContext: context)
            return (chatData, appContext)
        }
        
        // Get the prepared data
        let (chatData, appContext) = prepareData()
        
        // Return the preview
        return NavigationStack {
            ChatView(chat: chatData)
                .environmentObject(appContext)
        }
        .modelContainer(container)
    }
}
