//
//  SmallProfilePictureView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

struct SmallProfilePictureView: View {
    @Environment(ProfilePictureCacheService.self) private var profilePictureCacheService

    private let profile: Profile?
    private let action: () -> Void

    private var displayedImage: UIImage? {
        guard
            let profilePicturePath = profile?.picture,
            let profilePicture = profilePictureCacheService.profilePictures[
                profilePicturePath],
            let image = UIImage(data: profilePicture.data)
        else {
            return nil
        }
        return image
    }

     init(for profile: Profile?, action: @escaping () -> Void) {
         self.profile = profile
         self.action = action
     }

    var body: some View {
        RoundImageButton(uiImage: displayedImage, action: action)
    }
}
