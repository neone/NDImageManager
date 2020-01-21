//
//  FiltersView.swift
//  CIFilterImage
//
//  Created by Dave Glassco on 1/18/20.
//  Copyright © 2020 Tsubasa Hayashi. All rights reserved.
//

import UIKit

public protocol FiltersViewDelegate {
    func didFinish(_ image: UIImage)
    func didCancel()
}

public class FiltersView: UIView {
    
    private var collectionView: UICollectionView!
    public var image: UIImage!
    var filterPreviews: [UIImage] = []
    
    private var selectedFilterIndex = 0
    private var smallImage = UIImage()
    
    var filtersViewDelegate: FiltersViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.black
        
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func willMove(toSuperview newSuperview: UIView?) {
        configureUI()
    }
    
    private func configureUI() {
        
        
        let cellHeight = self.bounds.height
        let cellWidth = cellHeight * 0.6
        
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = CGSize(width: cellWidth, height: cellHeight)
        flowLayout.minimumLineSpacing = 12
        flowLayout.minimumInteritemSpacing = 12
        flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        flowLayout.scrollDirection = .horizontal
        
        collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: flowLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        
        if #available(iOS 13, *) {
            collectionView.backgroundColor = UIColor.systemBackground
        } else {
            collectionView.backgroundColor = UIColor.clear
        }
        
        self.addSubview(collectionView)
        
        collectionView.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor).isActive = true
        collectionView.heightAnchor.constraint(equalToConstant: self.bounds.height).isActive = true
        
        
        collectionView.register(CIFilterCollectionViewCell.self, forCellWithReuseIdentifier: "CIFilterCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        
        smallImage = UIImage.resize(with: image, ratio: 0.2)
    }
    
    private func applyFilterImageView() {
        let filter = Filter.all[selectedFilterIndex]
        DispatchQueue.global().async { [weak self] in
            let filteredImage = CIFilterService.shared.applyFilter(with: self?.image ?? UIImage(), filter: filter)
            if let correctedImage = filteredImage.fixedOrientation() {
                DispatchQueue.main.async {
                    self?.filtersViewDelegate?.didFinish(correctedImage)
                }
            } else {
                DispatchQueue.main.async {
                    self?.filtersViewDelegate?.didFinish(filteredImage)
                }
            }
        }
    }
}


extension FiltersView: UICollectionViewDataSource, UICollectionViewDelegate
{
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CIFilterCell", for: indexPath) as! CIFilterCollectionViewCell
        let filter = Filter.all[indexPath.row]
        let isSelected = indexPath.row == selectedFilterIndex
        cell.configure(filter: filter, isSelected: isSelected)
       
        DispatchQueue.global().async { [weak self, weak cell] in
            var filteredImage = self?.smallImage
            filteredImage = CIFilterService.shared.applyFilter(with: filteredImage!, filter: filter)
            DispatchQueue.main.async {
                cell?.configure(filter: filter, isSelected: isSelected)
                cell?.setImage(with: filteredImage)
                
            }
        }
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Filter.all.count
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedFilterIndex = indexPath.row
        applyFilterImageView()
        scrollTo(index: indexPath.item)
        collectionView.reloadData()
    }
    
    func scrollTo(index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
}
