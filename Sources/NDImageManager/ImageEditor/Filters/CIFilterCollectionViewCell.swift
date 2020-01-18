//
//  CIFilterCollectionViewCell.swift
//  CIFilterImage
//
//  Created by Tsubasa Hayashi on 2019/03/29.
//  Copyright © 2019 Tsubasa Hayashi. All rights reserved.
//

import UIKit

class CIFilterCollectionViewCell: UICollectionViewCell {
    
    static var identifier: String = "CIFilterCell"
    
    private var filterNameLabel: UILabel!
    private var imageView: UIImageView!
    private var cellWidth: CGFloat!
    
    //MARK: Initializers and Overrides
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        imageView.image = nil
        super.prepareForReuse()
    }
    
    
    
    //MARK: Class Methods
    func configureUI() {
        
        let cellStack = UIStackView()
        
        cellStack.axis = .vertical
        cellStack.alignment = .center
        self.contentView.addSubview(cellStack)
        cellStack.bindFrameToSuperviewBounds()
        
        cellWidth = cellStack.bounds.width
        imageView = UIImageView()
        imageView.frame = CGRect(x: 0, y: 0, width: cellStack.bounds.width, height:cellStack.bounds.width)
        imageView.layer.cornerRadius = 5
   
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        

        filterNameLabel = UILabel()
        
        filterNameLabel.textColor = UIColor.white
        
        cellStack.addArrangedSubviews([filterNameLabel, imageView])
        
    }
    
    func configure(filter: Filter, textColor: UIColor, isSelected: Bool) {
        filterNameLabel.text = filter.name
//        filterNameLabel.textColor = textColor
        filterNameLabel.font = isSelected ? UIFont.boldSystemFont(ofSize: 11) : UIFont.systemFont(ofSize: 11, weight: .thin)
    }
    
    func configure(filter: Filter, isSelected: Bool) {
        filterNameLabel.text = filter.name
        filterNameLabel.font = isSelected ? UIFont.boldSystemFont(ofSize: 11) : UIFont.systemFont(ofSize: 11, weight: .thin)
    }
    
    func setImage(with image: UIImage?) {
        imageView.image = image
        imageView.frame = CGRect(x: 0, y: 0, width: cellWidth, height: cellWidth)
        imageView.layer.cornerRadius = 5
        
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
    }
}

extension UIView {
    
    /// Adds constraints to this `UIView` instances `superview` object to make sure this always has the same size as the superview.
    /// Please note that this has no effect if its `superview` is `nil` – add this `UIView` instance as a subview before calling this.
    func bindFrameToSuperviewBounds() {
        guard let superview = self.superview else {
            print("Error! `superview` was nil – call `addSubview(view: UIView)` before calling `bindFrameToSuperviewBounds()` to fix this.")
            return
        }

        self.translatesAutoresizingMaskIntoConstraints = false
        self.topAnchor.constraint(equalTo: superview.topAnchor, constant: 0).isActive = true
        self.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: 0).isActive = true
        self.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 0).isActive = true
        self.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: 0).isActive = true

    }
}

public extension UIStackView {
    /// SwifterSwift: Adds array of views to the end of the arrangedSubviews array.
    ///
    /// - Parameter views: views array.
    func addArrangedSubviews(_ views: [UIView]) {
        for view in views {
            addArrangedSubview(view)
        }
    }
}
