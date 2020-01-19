//
//  File.swift
//  
//
//  Created by Dave Glassco on 1/18/20.
//

import Foundation
import UIKit

// MARK: UIScrollViewDelegate

extension ImageEditorViewController: UIScrollViewDelegate {

    public func viewForZooming(in _: UIScrollView) -> UIView? {
        return imageView
    }

    public func scrollViewWillBeginZooming(_: UIScrollView, with _: UIView?) {
        cancelStasis()
        overlay.blur = false
        overlay.gridLinesAlpha = 1
        topBar.isUserInteractionEnabled = false
        bottomView.isUserInteractionEnabled = false
    }

    public func scrollViewDidEndZooming(_: UIScrollView, with _: UIView?, atScale _: CGFloat) {
        matchScrollViewAndCropView(animated: true, completion: {
            self.stasisAndThenRun {
                UIView.animate(withDuration: 0.25, animations: {
                    self.overlay.gridLinesAlpha = 0
                    self.overlay.blur = true
                }, completion: { _ in
                    self.topBar.isUserInteractionEnabled = true
                    self.bottomView.isUserInteractionEnabled = true
                    self.updateButtons()
                })

                self.manualZoomed = true
            }
        })
    }

    public func scrollViewWillBeginDragging(_: UIScrollView) {
        cancelStasis()
        overlay.blur = false
        overlay.gridLinesAlpha = 1
        topBar.isUserInteractionEnabled = false
        bottomView.isUserInteractionEnabled = false
    }

    public func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            matchScrollViewAndCropView(animated: true, completion: {
                self.stasisAndThenRun {
                    UIView.animate(withDuration: 0.25, animations: {
                        self.overlay.gridLinesAlpha = 0
                        self.overlay.blur = true
                    }, completion: { _ in
                        self.topBar.isUserInteractionEnabled = true
                        self.bottomView.isUserInteractionEnabled = true
                        self.updateButtons()
                    })
                }
            })
        }
    }

    public func scrollViewDidEndDecelerating(_: UIScrollView) {
        matchScrollViewAndCropView(animated: true, completion: {
            self.stasisAndThenRun {
                UIView.animate(withDuration: 0.25, animations: {
                    self.overlay.gridLinesAlpha = 0
                    self.overlay.blur = true
                }, completion: { _ in
                    self.topBar.isUserInteractionEnabled = true
                    self.bottomView.isUserInteractionEnabled = true
                    self.updateButtons()
                })
            }
        })
    }
}

// MARK: UIGestureRecognizerDelegate

extension ImageEditorViewController: UIGestureRecognizerDelegate {

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == cropBoxPanGesture {
            guard isCropBoxPanEnabled else {
                return false
            }
            let tapPoint = gestureRecognizer.location(in: view)

            let frame = overlay.cropBoxFrame

            let d = cropBoxHotArea / 2.0
            let innerFrame = frame.insetBy(dx: d, dy: d)
            let outerFrame = frame.insetBy(dx: -d, dy: -d)

            if innerFrame.contains(tapPoint) || !outerFrame.contains(tapPoint) {
                return false
            }
        }

        return true
    }
}

// MARK: AspectRatioPickerDelegate

extension ImageEditorViewController: AspectRatioPickerDelegate {

    func aspectRatioPickerDidSelectedAspectRatio(_ aspectRatio: AspectRatio) {
        setAspectRatio(aspectRatio)
    }
}


extension ImageEditorViewController {
    
    public func didFinish(_ image: UIImage) {
        imageView.image = image
        selectedImage = image
        toolbar.resetButton.isHidden = false
    }
    
    public func didCancel() {}
}
