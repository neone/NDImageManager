//
//  File.swift
//  
//
//  Created by Dave Glassco on 1/18/20.
//

import UIKit

extension ImageEditorViewController {
    
    //MARK: Angle Ruler
    @objc
      func angleRulerValueChanged(_: AnyObject) {
          toolbar.isUserInteractionEnabled = false
          topBar.isUserInteractionEnabled = false
          scrollViewContainer.isUserInteractionEnabled = false
          setStraightenAngle(CGFloat(angleRuler.value * CGFloat.pi / 180.0))
      }

      @objc
      func angleRulerTouchEnded(_: AnyObject) {
          UIView.animate(withDuration: 0.25, animations: {
              self.overlay.gridLinesAlpha = 0
              self.overlay.blur = true
          }, completion: { _ in
              self.toolbar.isUserInteractionEnabled = true
              self.topBar.isUserInteractionEnabled = true
              self.scrollViewContainer.isUserInteractionEnabled = true
              self.overlay.gridLinesCount = 2
          })
      }
    
    //MARK: Scroll Views
    func scrollViewZoomScaleToBounds() -> CGFloat {
        let scaleW = scrollView.bounds.size.width / imageView.bounds.size.width
        let scaleH = scrollView.bounds.size.height / imageView.bounds.size.height
        return max(scaleW, scaleH)
    }
    
    func willSetScrollViewZoomScale(_ zoomScale: CGFloat) {
        if zoomScale > scrollView.maximumZoomScale {
            scrollView.maximumZoomScale = zoomScale
        }
        if zoomScale < scrollView.minimumZoomScale {
            scrollView.minimumZoomScale = zoomScale
        }
    }
    
    public func matchScrollViewAndCropView(animated: Bool = false,
                                    targetCropBoxFrame: CGRect = overlayCropBoxFramePlaceholder,
                                    extraZoomScale: CGFloat = 1.0,
                                    blurLayerAnimated: Bool = false,
                                    animations: (() -> Void)? = nil,
                                    completion: (() -> Void)? = nil) {
        var targetCropBoxFrame = targetCropBoxFrame
        if targetCropBoxFrame.equalTo(ImageEditorViewController.overlayCropBoxFramePlaceholder) {
            targetCropBoxFrame = overlay.cropBoxFrame
        }

        let scaleX = maxCropRegion.size.width / targetCropBoxFrame.size.width
        let scaleY = maxCropRegion.size.height / targetCropBoxFrame.size.height

        let scale = min(scaleX, scaleY)

        // calculate the new bounds of crop view
        let newCropBounds = CGRect(x: 0, y: 0, width: scale * targetCropBoxFrame.size.width, height: scale * targetCropBoxFrame.size.height)

        // calculate the new bounds of scroll view
        let rotatedRect = newCropBounds.applying(CGAffineTransform(rotationAngle: totalAngle))
        let width = rotatedRect.size.width
        let height = rotatedRect.size.height

        let cropBoxFrameBeforeZoom = targetCropBoxFrame

        let zoomRect = view.convert(cropBoxFrameBeforeZoom, to: imageView) // zoomRect is base on imageView when scrollView.zoomScale = 1
        let center = CGPoint(x: zoomRect.origin.x + zoomRect.size.width / 2, y: zoomRect.origin.y + zoomRect.size.height / 2)
        let normalizedCenter = CGPoint(x: center.x / (imageView.width / scrollView.zoomScale), y: center.y / (imageView.height / scrollView.zoomScale))

        UIView.animate(withDuration: animated ? 0.25 : 0, animations: {
            self.overlay.setCropBoxFrame(CGRect(center: self.defaultCropBoxCenter, size: newCropBounds.size), blurLayerAnimated: blurLayerAnimated)
            animations?()
            self.scrollView.bounds = CGRect(x: 0, y: 0, width: width, height: height)

            var zoomScale = scale * self.scrollView.zoomScale * extraZoomScale
            let scrollViewZoomScaleToBounds = self.scrollViewZoomScaleToBounds()
            if zoomScale < scrollViewZoomScaleToBounds { // Some are not image in the cropbox area
                zoomScale = scrollViewZoomScaleToBounds
            }
            if zoomScale > self.scrollView.maximumZoomScale { // Only rotate can make maximumZoomScale to get bigger
                zoomScale = self.scrollView.maximumZoomScale
            }
            self.willSetScrollViewZoomScale(zoomScale)

            self.scrollView.zoomScale = zoomScale

            let contentOffset = CGPoint(x: normalizedCenter.x * self.imageView.width - self.scrollView.bounds.size.width * 0.5,
                                        y: normalizedCenter.y * self.imageView.height - self.scrollView.bounds.size.height * 0.5)
            self.scrollView.contentOffset = self.safeContentOffsetForScrollView(contentOffset)
        }, completion: { _ in
            completion?()
        })

        manualZoomed = true
    }

    func safeContentOffsetForScrollView(_ contentOffset: CGPoint) -> CGPoint {
        var contentOffset = contentOffset
        contentOffset.x = max(contentOffset.x, 0)
        contentOffset.y = max(contentOffset.y, 0)

        if scrollView.contentSize.height - contentOffset.y <= scrollView.bounds.size.height {
            contentOffset.y = scrollView.contentSize.height - scrollView.bounds.size.height
        }

        if scrollView.contentSize.width - contentOffset.x <= scrollView.bounds.size.width {
            contentOffset.x = scrollView.contentSize.width - scrollView.bounds.size.width
        }

        return contentOffset
    }

    //MARK: Crop Box
    func safeCropBoxFrame(_ cropBoxFrame: CGRect) -> CGRect {
        var cropBoxFrame = cropBoxFrame
        // Upon init, sometimes the box size is still 0, which can result in CALayer issues
        if cropBoxFrame.size.width < .ulpOfOne || cropBoxFrame.size.height < .ulpOfOne {
            return CGRect(center: defaultCropBoxCenter, size: defaultCropBoxSize)
        }

        // clamp the cropping region to the inset boundaries of the screen
        let contentFrame = maxCropRegion
        let xOrigin = contentFrame.origin.x
        let xDelta = cropBoxFrame.origin.x - xOrigin
        cropBoxFrame.origin.x = max(cropBoxFrame.origin.x, xOrigin)
        if xDelta < -.ulpOfOne { // If we clamp the x value, ensure we compensate for the subsequent delta generated in the width (Or else, the box will keep growing)
            cropBoxFrame.size.width += xDelta
        }

        let yOrigin = contentFrame.origin.y
        let yDelta = cropBoxFrame.origin.y - yOrigin
        cropBoxFrame.origin.y = max(cropBoxFrame.origin.y, yOrigin)
        if yDelta < -.ulpOfOne {
            cropBoxFrame.size.height += yDelta
        }

        // given the clamped X/Y values, make sure we can't extend the crop box beyond the edge of the screen in the current state
        let maxWidth = (contentFrame.size.width + contentFrame.origin.x) - cropBoxFrame.origin.x
        cropBoxFrame.size.width = min(cropBoxFrame.size.width, maxWidth)

        let maxHeight = (contentFrame.size.height + contentFrame.origin.y) - cropBoxFrame.origin.y
        cropBoxFrame.size.height = min(cropBoxFrame.size.height, maxHeight)

        // Make sure we can't make the crop box too small
        cropBoxFrame.size.width = max(cropBoxFrame.size.width, cropBoxMinSize)
        cropBoxFrame.size.height = max(cropBoxFrame.size.height, cropBoxMinSize)

        return cropBoxFrame
    }
    
    @objc
    func cropBoxPan(_ pan: UIPanGestureRecognizer) {
        guard isCropBoxPanEnabled else {
            return
        }
        let point = pan.location(in: view)
        
        if pan.state == .began {
            cancelStasis()
            panBeginningPoint = point
            panBeginningCropBoxFrame = overlay.cropBoxFrame
            panBeginningCropBoxEdge = nearestCropBoxEdgeForPoint(point: panBeginningPoint)
            overlay.blur = false
            overlay.gridLinesAlpha = 1
            topBar.isUserInteractionEnabled = false
            bottomView.isUserInteractionEnabled = false
        }
        
        if pan.state == .ended || pan.state == .cancelled {
            stasisAndThenRun {
                self.matchScrollViewAndCropView(animated: true, targetCropBoxFrame: self.overlay.cropBoxFrame, extraZoomScale: 1, blurLayerAnimated: true, animations: {
                    self.overlay.gridLinesAlpha = 0
                    self.overlay.blur = true
                }, completion: {
                    self.topBar.isUserInteractionEnabled = true
                    self.bottomView.isUserInteractionEnabled = true
                    self.updateButtons()
                })
            }
        } else {
            updateCropBoxFrameWithPanGesturePoint(point)
        }
    }
    
    //MARK: Buttons
    func updateButtons() {
           if let toolbar = self.toolbar as? Toolbar {
               toolbar.resetButton.isHidden = isCurrentlyInDefalutState
               if initialState != nil {
                   toolbar.doneButton.isEnabled = !isCurrentlyInInitialState
               } else {
                   toolbar.doneButton.isEnabled = true//!isCurrentlyInDefalutState
               }
           }
       }
    
    @objc
    func cancelButtonPressed(_: UIButton) {
        delegate?.editorDidCancel(self)
    }
    
    @objc
    func confirmButtonPressed(_: UIButton) {
        delegate?.editorDidConfirm(self, state: saveState())
    }
    
    @objc
    func resetButtonPressed(_: UIButton) {
        overlay.blur = false
        overlay.gridLinesAlpha = 0
        overlay.cropBoxAlpha = 0
        topBar.isUserInteractionEnabled = false
        bottomView.isUserInteractionEnabled = false
        
        UIView.animate(withDuration: 0.25, animations: {
            self.resetToDefaultLayout()
        }, completion: { _ in
            UIView.animate(withDuration: 0.25, animations: {
                self.overlay.cropBoxAlpha = 1
                self.overlay.blur = true
            }, completion: { _ in
                self.topBar.isUserInteractionEnabled = true
                self.bottomView.isUserInteractionEnabled = true
            })
        })
    }
    
    @objc
    func flipButtonPressed(_: UIButton) {
        flip()
    }
    
    @objc
    func rotateButtonPressed(_: UIButton) {
        rotate90degrees()
    }
    
    @objc
    func imageFiltersButtonPressed(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        filterViewActive = !sender.isSelected
        filterViewActive = true
        if aspectViewActive {
            aspectViewActive = false
            aspectRatioPicker.isHidden = true
            topBar.aspectRationButton.isSelected = false
        }
        
        angleRuler.isHidden = sender.isSelected
        overlay.cropBox.isHidden = sender.isSelected
        overlay.blur = !sender.isSelected
//        overlay.backgroundColor = UIColor.black
        backgroundView.isUserInteractionEnabled = !sender.isSelected
        
        imageFiltersView.isHidden = !sender.isSelected
    }
    
    @objc
    func aspectRationButtonPressed(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        aspectViewActive = true
        if filterViewActive {
            filterViewActive = false
            imageFiltersView.isHidden = true
            topBar.imageFiltersButton.isSelected = false
        }
        
        backgroundView.isUserInteractionEnabled = true
        angleRuler.isHidden = sender.isSelected
        aspectRatioPicker.isHidden = !sender.isSelected
    }
    
    //MARK: Photos
    func photoTranslation() -> CGPoint {
        let rect = imageView.convert(imageView.bounds, to: view)
        let point = CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
        let zeroPoint = CGPoint(x: view.frame.width / 2, y: defaultCropBoxCenter.y)

        return CGPoint(x: point.x - zeroPoint.x, y: point.y - zeroPoint.y)
    }

}
