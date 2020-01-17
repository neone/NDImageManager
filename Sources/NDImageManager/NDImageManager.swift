//
//  NDImageManager.swift
//  NDImageManager
//
//  Created by Dave Glassco on 1/17/20.
//  Copyright © 2020 Neone. All rights reserved.
//

import UIKit

protocol NDImagePickerDelegate {
    func editedImageReturned(image: UIImage)
}

class NDImageManager: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CropperViewControllerDelegate {

    var cropperState: CropperState?
    fileprivate var shouldPickImage = true
    fileprivate var shouldShowEdit = false
    fileprivate var isRounded = false
    
    var imagePickerDelegate: NDImagePickerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        launchImagePicker()
    }
    
    
    /// Public Setup Method - this is how NDImageManager should be set from outside the framework
    /// - Parameters:
    ///   - editable: sets whether edit window called after picker
    ///   - rounded: set edit window crop to round only
    public func setUpImageManager(editable: Bool, rounded: Bool ) {
        if editable {
            shouldShowEdit = true
        }
        if rounded {
            isRounded = true
        }
    }
    
    
    //Private Class Methods
    fileprivate func launchImagePicker() {
        let picker = UIImagePickerController()
               picker.sourceType = .photoLibrary
               picker.allowsEditing = false
               picker.delegate = self
               present(picker, animated: true, completion: nil)
    }
    
    fileprivate func showQCropper(_ image: UIImage,) {
        //Setup the QCropper View
        let cropper = CropperViewController(originalImage: image)
        cropper.delegate = self
        
        if isRounded {
            cropper.isCircular = true
        }
        self.present(cropper, animated: true, completion: nil)
    }
}


//MARK: ImagePickerDelegate
extension NDImageManager {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
           guard let image = (info[.originalImage] as? UIImage) else { return }
        
        picker.dismiss(animated: true) {
            if self.shouldShowEdit {
                showQCropper()
            } else {
                self.imagePickerDelegate?.editedImageReturned(image: image)
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
}


//MARK: CropperViewDelegate
extension NDImageManager {
    func cropperDidConfirm(_ cropper: CropperViewController, state: CropperState?) {
        cropper.dismiss(animated: true, completion: nil)

        if let state = state,
            let image = cropper.originalImage.cropped(withCropperState: state) {
            cropperState = state
            imagePickerDelegate?.editedImageReturned(image: image)
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func cropperDidCancel(_ cropper: CropperViewController) {
        cropper.dismiss(animated: true, completion: nil)
        self.dismiss(animated: true, completion: nil)
    }
}
