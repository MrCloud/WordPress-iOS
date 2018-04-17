import Foundation
import Photos

extension PostSettingsViewController {

    @objc func setFeaturedImage(asset: PHAsset) {
        if let receipt = mediaObserverReceipt {
            MediaCoordinator.shared.removeObserver(withUUID: receipt)
        }
        isUploadingMedia = true
        let media = MediaCoordinator.shared.addMedia(from: asset, to: self.apost)
        mediaObserverReceipt = MediaCoordinator.shared.addObserver({ [weak self](media, state) in
            self?.mediaObserver(media: media, state: state)
        }, for: media)
        let progress = MediaCoordinator.shared.progress(for: media)
        self.featuredImageProgress = progress
    }

    @objc func setFeaturedImage(media: Media) {
        if let receipt = mediaObserverReceipt {
            MediaCoordinator.shared.removeObserver(withUUID: receipt)
        }
        if media.hasRemote {
            apost.featuredImage = media
            return
        }
        isUploadingMedia = true
        MediaCoordinator.shared.retryMedia(media)
        mediaObserverReceipt = MediaCoordinator.shared.addObserver({ [weak self](media, state) in
            self?.mediaObserver(media: media, state: state)
        })
        let progress = MediaCoordinator.shared.progress(for: media)
        self.featuredImageProgress = progress
    }

    func mediaObserver(media: Media, state: MediaCoordinator.MediaState) {
        switch state {
        case .processing:
            featuredImageProgress?.localizedDescription = NSLocalizedString("Preparing...", comment: "Label to show while converting and/or resizing media to send to server")
        case .thumbnailReady:
            if let url = media.absoluteThumbnailLocalURL, let data = try? Data(contentsOf: url) {
                featuredImageProgress?.setUserInfoObject(UIImage(data: data), forKey: .WPProgressImageThumbnailKey)
            }
        case .uploading(let progress):
            featuredImageProgress = progress
            featuredImageProgress?.kind = .file
            featuredImageProgress?.setUserInfoObject(Progress.FileOperationKind.copying, forKey: ProgressUserInfoKey.fileOperationKindKey)
            featuredImageProgress?.localizedDescription = NSLocalizedString("Uploading...", comment: "Label to show while uploading media to server")
            tableView.reloadData()
        case .ended:
            apost.featuredImage = media
            isUploadingMedia = false
            tableView.reloadData()
        case .failed(let error):
            DDLogError("Couldn't export image: /(error.localizedDescription)")
            isUploadingMedia = false
            tableView.reloadData()
            if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                break
            }
            WPError.showAlert(withTitle: NSLocalizedString("Couldn't upload featured image", comment: "The title for an alert that says to the user that the featured image he selected couldn't be uploaded."), message: error.localizedDescription)
        case .progress:
            break
        }
    }

}