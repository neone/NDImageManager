//
//  Constans.swift
//
//  Created by Chen Qizhi on 2019/10/15.
//

import UIKit

let croppingImageShortSideMaxSize: CGFloat = 1280
let croppingImageLongSideMaxSize: CGFloat = 5120 // 1280 * 4

let highlightColor = UIColor(red: 249 / 255.0, green: 214 / 255.0, blue: 74 / 255.0, alpha: 1)

let resourceBundle = Bundle(for: ImageEditorViewController.self)

enum CropBoxEdge: Int {
    case none
    case left
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
}
