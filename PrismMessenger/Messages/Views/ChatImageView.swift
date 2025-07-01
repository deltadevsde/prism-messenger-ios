//
//  ChatImageView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

struct ChatImageView: View {
    @EnvironmentObject private var router: NavigationRouter
    @Environment(ProfileCacheService.self) private var profileCacheService
    @Environment(ProfilePictureCacheService.self) private var profilePictureCacheService

    @Bindable var chat: Chat

    private var displayedImageUrl: String? {
        return chat.imageURL ?? profileCacheService.profiles[chat.participantId]?.picture
    }

    private var displayedImage: UIImage? {
        if let profile = profileCacheService.profiles[chat.participantId],
            let picturePath = profile.picture,
            let profilePicture = profilePictureCacheService.profilePictures[picturePath]
        {
            return UIImage(data: profilePicture.data)
        }

        // TODO: Use chat.imageURL when it can be changed
        return nil
    }

    var body: some View {
        RoundImageButton(uiImage: displayedImage) {
            router.openProfile(chat.participantId)
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
