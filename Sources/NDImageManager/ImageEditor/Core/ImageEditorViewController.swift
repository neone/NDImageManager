//
//  ImageEditorViewController.swift
//
//  Created by Chen Qizhi on 2019/10/15.
//

import UIKit



public protocol ImageEditorDelegate: class {
    func editorDidConfirm(_ cropper: ImageEditorViewController, state: CropperState?)
    func editorDidCancel(_ cropper: ImageEditorViewController)
}


open class ImageEditorViewController: UIViewController, Rotatable, StateRestorable, Flipable {

    //MARK: Variables and Outlets
    public let originalImage: UIImage
    
    var initialState: CropperState?
    var isCircular: Bool
    var filterViewActive = false
    var aspectViewActive = false

    public weak var delegate: ImageEditorDelegate?

    // if self not init with a state, return false
    open var isCurrentlyInInitialState: Bool {
        isCurrentlyInState(initialState)
    }

    public var aspectRatioLocked: Bool = false {
        didSet {
            overlay.free = !aspectRatioLocked
        }
    }

    public var currentAspectRatioValue: CGFloat = 1.0
    public var isCropBoxPanEnabled: Bool = true
    public var cropContentInset: UIEdgeInsets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

    let cropBoxHotArea: CGFloat = 50
    let cropBoxMinSize: CGFloat = 20
    let barHeight: CGFloat = 44

    var cropRegionInsets: UIEdgeInsets = .zero
    var maxCropRegion: CGRect = .zero
    var defaultCropBoxCenter: CGPoint = .zero
    var defaultCropBoxSize: CGSize = .zero

    var straightenAngle: CGFloat = 0.0
    var rotationAngle: CGFloat = 0.0
    var flipAngle: CGFloat = 0.0

    var panBeginningPoint: CGPoint = .zero
    var panBeginningCropBoxEdge: CropBoxEdge = .none
    var panBeginningCropBoxFrame: CGRect = .zero

    var manualZoomed: Bool = false

    var needReload: Bool = false
    var defaultCropperState: CropperState?
    var stasisTimer: Timer?
    var stasisThings: (() -> Void)?

    open var isCurrentlyInDefalutState: Bool {
        isCurrentlyInState(defaultCropperState)
    }

    var totalAngle: CGFloat {
        return autoHorizontalOrVerticalAngle(straightenAngle + rotationAngle + flipAngle)
    }

    lazy var scrollViewContainer: ScrollViewContainer = ScrollViewContainer(frame: self.view.bounds)

    lazy var scrollView: UIScrollView = {
        let sv = UIScrollView(frame: CGRect(x: 0, y: 0, width: self.defaultCropBoxSize.width, height: self.defaultCropBoxSize.height))
        sv.delegate = self
        sv.center = self.backgroundView.convert(defaultCropBoxCenter, to: scrollViewContainer)
        sv.bounces = true
        sv.bouncesZoom = true
        sv.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sv.alwaysBounceVertical = true
        sv.alwaysBounceHorizontal = true
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 20
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.clipsToBounds = false
        sv.contentSize = self.defaultCropBoxSize
        //// debug
        // sv.layer.borderColor = UIColor.green.cgColor
        // sv.layer.borderWidth = 1
        // sv.showsVerticalScrollIndicator = true
        // sv.showsHorizontalScrollIndicator = true

        return sv
    }()

    lazy var imageView: UIImageView = {
        let iv = UIImageView(image: self.originalImage)
        iv.backgroundColor = .clear
        return iv
    }()

    lazy var cropBoxPanGesture: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(cropBoxPan(_:)))
        pan.delegate = self
        return pan
    }()

    // MARK: Custom UI

    lazy var backgroundView: UIView = {
        let view = UIView(frame: self.view.bounds)
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)
        return view
    }()

    open lazy var bottomView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: self.view.height - 100, width: self.view.width, height: 100))
        view.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleWidth]
        return view
    }()

    open lazy var topBar: TopBar = {
        let topBar = TopBar(frame: CGRect(x: 0, y: 0, width: self.view.width, height: self.view.safeAreaInsets.top + barHeight))
        topBar.flipButton.addTarget(self, action: #selector(flipButtonPressed(_:)), for: .touchUpInside)
        topBar.rotateButton.addTarget(self, action: #selector(rotateButtonPressed(_:)), for: .touchUpInside)
        topBar.imageFiltersButton.addTarget(self, action: #selector(imageFiltersButtonPressed(_:)), for: .touchUpInside)
        topBar.aspectRationButton.addTarget(self, action: #selector(aspectRationButtonPressed(_:)), for: .touchUpInside)
        return topBar
    }()

    open lazy var toolbar: UIView = {
        let toolbar = Toolbar(frame: CGRect(x: 0, y: 0, width: self.view.width, height: view.safeAreaInsets.bottom + barHeight))
        toolbar.doneButton.addTarget(self, action: #selector(confirmButtonPressed(_:)), for: .touchUpInside)
        toolbar.cancelButton.addTarget(self, action: #selector(cancelButtonPressed(_:)), for: .touchUpInside)
        toolbar.resetButton.addTarget(self, action: #selector(resetButtonPressed(_:)), for: .touchUpInside)

        return toolbar
    }()

    let verticalAspectRatios: [AspectRatio] = [
        .original,
        .freeForm,
        .square,
        .ratio(width: 9, height: 16),
        .ratio(width: 8, height: 10),
        .ratio(width: 5, height: 7),
        .ratio(width: 3, height: 4),
        .ratio(width: 3, height: 5),
        .ratio(width: 2, height: 3)
    ]

    open lazy var overlay: Overlay = Overlay(frame: self.view.bounds)

    public lazy var imageFiltersView: FiltersView = {
        let filterPicker = FiltersView(frame: CGRect(x: 0, y: 0, width: view.width, height: 80))
        return filterPicker
    }()
    
    public lazy var angleRuler: AngleRuler = {
        let ar = AngleRuler(frame: CGRect(x: 0, y: 0, width: view.width, height: 80))
        ar.addTarget(self, action: #selector(angleRulerValueChanged(_:)), for: .valueChanged)
        ar.addTarget(self, action: #selector(angleRulerTouchEnded(_:)), for: [.editingDidEnd])
        return ar
    }()

    public lazy var aspectRatioPicker: AspectRatioPicker = {
        let picker = AspectRatioPicker(frame: CGRect(x: 0, y: 0, width: view.width, height: 80))
        picker.isHidden = true
        picker.delegate = self
        return picker
    }()


    //MARK: Initializers and Overrides

    deinit {
        self.cancelStasis()
    }

    public init(originalImage: UIImage, initialState: CropperState? = nil, isCircular: Bool = false) {
        self.originalImage = originalImage
        self.initialState = initialState
        self.isCircular = isCircular
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.isHidden = true
        view.clipsToBounds = true

        // TODO: transition

        if originalImage.size.width < 1 || originalImage.size.height < 1 {
            // TODO: show alert and dismiss
            return
        }

        topBar.aspectRationButton.isSelected = false
        
        view.backgroundColor = .clear

        scrollView.addSubview(imageView)

        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }

        scrollViewContainer.scrollView = scrollView
        scrollViewContainer.addSubview(scrollView)
        scrollViewContainer.addGestureRecognizer(cropBoxPanGesture)
        scrollView.panGestureRecognizer.require(toFail: cropBoxPanGesture)

        backgroundView.addSubview(scrollViewContainer)
        backgroundView.addSubview(overlay)
        bottomView.addSubview(imageFiltersView)
        imageFiltersView.isHidden = true
        bottomView.addSubview(aspectRatioPicker)
        bottomView.addSubview(angleRuler)
        bottomView.addSubview(toolbar)

        view.addSubview(backgroundView)
        view.addSubview(bottomView)
        view.addSubview(topBar)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Layout when self.view finish layout and never layout before, or self.view need reload
        if let viewFrame = defaultCropperState?.viewFrame,
            viewFrame.equalTo(view.frame) {
            if needReload {
                // TODO: reload but keep crop box
                needReload = false
                resetToDefaultLayout()
            }
        } else {
            // TODO: suppport multi oriention
            resetToDefaultLayout()

            if let initialState = initialState {
                restoreState(initialState)
                updateButtons()
            }
        }
    }

    public override var prefersStatusBarHidden: Bool {
        return true
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    public override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .top
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if !view.size.isEqual(to: size, accuracy: 0.0001) {
            needReload = true
        }
        super.viewWillTransition(to: size, with: coordinator)
    }

    

// MARK: - Private Methods

    open var cropBoxFrame: CGRect {
        get {
            return overlay.cropBoxFrame
        }
        set {
            overlay.cropBoxFrame = safeCropBoxFrame(newValue)
        }
    }

    open func resetToDefaultLayout() {
        let margin: CGFloat = 20

        topBar.frame = CGRect(x: 0, y: 0, width: view.width, height: view.safeAreaInsets.top + barHeight)
        toolbar.size = CGSize(width: view.width, height: view.safeAreaInsets.bottom + barHeight)
        bottomView.size = CGSize(width: view.width, height: toolbar.height + angleRuler.height + margin)
        bottomView.bottom = view.height
        toolbar.bottom = bottomView.height
        angleRuler.bottom = toolbar.top - margin
        aspectRatioPicker.frame = angleRuler.frame
        imageFiltersView.frame = angleRuler.frame

        let topHeight = topBar.isHidden ? view.safeAreaInsets.top : topBar.height
        let toolbarHeight = toolbar.isHidden ? view.safeAreaInsets.bottom : toolbar.height
        let bottomHeight = (angleRuler.isHidden && aspectRatioPicker.isHidden) ? toolbarHeight : bottomView.height
        cropRegionInsets = UIEdgeInsets(top: cropContentInset.top + topHeight,
                                        left: cropContentInset.left + view.safeAreaInsets.left,
                                        bottom: cropContentInset.bottom + bottomHeight,
                                        right: cropContentInset.right + view.safeAreaInsets.right)

        maxCropRegion = CGRect(x: cropRegionInsets.left,
                               y: cropRegionInsets.top,
                               width: view.width - cropRegionInsets.left - cropRegionInsets.right,
                               height: view.height - cropRegionInsets.top - cropRegionInsets.bottom)
        defaultCropBoxCenter = CGPoint(x: view.width / 2.0, y: cropRegionInsets.top + maxCropRegion.size.height / 2.0)
        defaultCropBoxSize = {
            var size: CGSize
            let scaleW = self.originalImage.size.width / self.maxCropRegion.size.width
            let scaleH = self.originalImage.size.height / self.maxCropRegion.size.height
            let scale = max(scaleW, scaleH)
            size = CGSize(width: self.originalImage.size.width / scale, height: self.originalImage.size.height / scale)
            return size
        }()

        backgroundView.frame = view.bounds
        scrollViewContainer.frame = CGRect(x: 0, y: topHeight, width: view.width, height: view.height - topHeight - bottomHeight)

        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 20
        scrollView.zoomScale = 1
        scrollView.transform = .identity
        scrollView.bounds = CGRect(x: 0, y: 0, width: defaultCropBoxSize.width, height: defaultCropBoxSize.height)
        scrollView.contentSize = defaultCropBoxSize
        scrollView.contentOffset = .zero
        scrollView.center = backgroundView.convert(defaultCropBoxCenter, to: scrollViewContainer)
        imageView.transform = .identity
        imageView.frame = scrollView.bounds
        overlay.frame = backgroundView.bounds
        overlay.cropBoxFrame = CGRect(center: defaultCropBoxCenter, size: defaultCropBoxSize)

        straightenAngle = 0
        rotationAngle = 0
        flipAngle = 0
        aspectRatioLocked = false
        currentAspectRatioValue = 1

        if isCircular {
            isCropBoxPanEnabled = true
            overlay.isCircular = true
            topBar.isHidden = true
            aspectRatioPicker.isHidden = true
            angleRuler.isHidden = false
            cropBoxFrame = CGRect(center: defaultCropBoxCenter, size: CGSize(width: maxCropRegion.size.width, height: maxCropRegion.size.width))
            matchScrollViewAndCropView()
        } else {
            if originalImage.size.width / originalImage.size.height < cropBoxMinSize / maxCropRegion.size.height { // very long
                cropBoxFrame = CGRect(x: (view.width - cropBoxMinSize) / 2, y: cropRegionInsets.top, width: cropBoxMinSize, height: maxCropRegion.size.height)
                matchScrollViewAndCropView()
            } else if originalImage.size.height / originalImage.size.width < cropBoxMinSize / maxCropRegion.size.width { // very wide
                cropBoxFrame = CGRect(x: cropRegionInsets.left, y: cropRegionInsets.top + (maxCropRegion.size.height - cropBoxMinSize) / 2, width: maxCropRegion.size.width, height: cropBoxMinSize)
                matchScrollViewAndCropView()
            }
        }

        defaultCropperState = saveState()

        angleRuler.value = 0
        if overlay.cropBoxFrame.size.width > overlay.cropBoxFrame.size.height {
            aspectRatioPicker.aspectRatios = verticalAspectRatios.map { $0.rotated }
        } else {
            aspectRatioPicker.aspectRatios = verticalAspectRatios
        }
        aspectRatioPicker.rotated = false
        aspectRatioPicker.selectedAspectRatio = .freeForm
        updateButtons()
    }

    public static let overlayCropBoxFramePlaceholder: CGRect = .zero
}


// MARK: Add capability from protocols

extension ImageEditorViewController: Stasisable, AngleAssist, CropBoxEdgeDraggable, AspectRatioSettable {}
