//
//  NDImageManager.swift
//  NDImageManager
//
//  Created by Dave Glassco on 1/17/20.
//  Copyright © 2020 Neone. All rights reserved.
//

import UIKit

public protocol NDImagePickerDelegate {
    func editedImageReturned(image: UIImage)
    func pickerCancelled()
}

public class NDImageManager: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ImageEditorDelegate {

    var cropperState: CropperState?
    fileprivate var shouldPickImage = true
    fileprivate var shouldShowEdit = false
    fileprivate var isRounded = false
    
    public var imagePickerDelegate: NDImagePickerDelegate?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        launchImagePicker()
    }
    
        
    /// Public Setup Method - this is how NDImageManager should be set from outside the framework
    /// - Parameters:
    ///   - editable: sets whether edit window called after picker
    ///   - rounded: set edit window crop to round only
    public func setUpImageManager(pickImage: Bool, editable: Bool, attachedImage: UIImage? = nil, rounded: Bool? = false ) {
        if editable {
            shouldShowEdit = true
        }
        if let shouldRound = rounded {
            isRounded = shouldRound
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
    
    fileprivate func showQCropper(_ image: UIImage) {
        //Setup the QCropper View
        let cropper = ImageEditorViewController(originalImage: image)
        cropper.delegate = self
        
        if isRounded {
            cropper.isCircular = true
        }
        self.present(cropper, animated: true, completion: nil)
    }
}


//MARK: ImagePickerDelegate
extension NDImageManager {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
           guard let image = (info[.originalImage] as? UIImage) else { return }
        
        var selectedImage = image
        
        if let fixedImage = selectedImage.fixedOrientation() {
            selectedImage = fixedImage
        }
        
        picker.dismiss(animated: true) {
            if self.shouldShowEdit {
                self.showQCropper(selectedImage)
            } else {
                self.imagePickerDelegate?.editedImageReturned(image: selectedImage)
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        self.dismiss(animated: true, completion: nil)
        self.imagePickerDelegate?.pickerCancelled()
    }
}


//MARK: CropperViewDelegate
extension NDImageManager {
    public func editorDidConfirm(_ cropper: ImageEditorViewController, state: CropperState?) {
        cropper.dismiss(animated: true, completion: nil)

        if let state = state,
            let image = cropper.selectedImage.cropped(withCropperState: state) {
            cropperState = state
            imagePickerDelegate?.editedImageReturned(image: image)
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    public func editorDidCancel(_ cropper: ImageEditorViewController) {
        cropper.dismiss(animated: true, completion: nil)
        self.dismiss(animated: true, completion: nil)
        self.imagePickerDelegate?.pickerCancelled()
    }
}
