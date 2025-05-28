//
//  ChatImageView.swift
//  PrismMessenger
//
//  Created by Jonas Pusch on 27.05.25.
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

struct ChatImageView: View {
    @EnvironmentObject private var router: NavigationRouter
    @Environment(ProfileService.self) private var profileService

    @Bindable var chat: Chat

    @State private var displayedImageUrl: String? = nil

    var body: some View {
        SmallProfilePictureView(imageURL: displayedImageUrl) {
            router.openProfile(chat.participantId)
        }
        .task {
            await updateDisplayedImage()
        }
    }

    private func updateDisplayedImage() async {
        // If chat has its own independent image, use that
        if let chatImageUrl = chat.imageURL {
            displayedImageUrl = chatImageUrl
            return
        }

        // otherwise, show the one from the participant
        do {
            let profile = try await profileService.fetchProfile(
                byAccountId: chat.participantId,
                usingLocalCache: false
            )
            displayedImageUrl = profile?.picture
            return
        } catch {
            Log.messages.warning(
                "Failed to load imageUrl for chat \(chat.id): \(error.localizedDescription)"
            )
        }
    }
}

#Preview {
    let chat = Chat(
        participantId: UUID(),
        displayName: "John Doe",
        imageURL: "http://example.localhost/image.jpg",
        doubleRatchetSession: Data()
    )

    AsyncPreview {
        ChatImageView(chat: chat)
    }
}
