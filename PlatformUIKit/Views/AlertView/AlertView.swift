//
//  AlertView.swift
//  PlatformUIKit
//
//  Created by Alex McGregor on 1/25/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

public class AlertView: UIView {
    
    // MARK: Private Static Properties
    
    fileprivate static let sheetBottomPadding: CGFloat = 16.0
    fileprivate static let titleTrailingPadding: CGFloat = 58.0
    fileprivate static let horizontalOffset: CGFloat = 32.0
    fileprivate static let horizontalPadding: CGFloat = 40.0
    fileprivate static let dismissableHeadlingPadding: CGFloat = 16.0
    fileprivate static let topToHeadlingPadding: CGFloat = 32.0
    fileprivate static let messageToActionsPadding: CGFloat = 24.0
    fileprivate static let actionsToBottomPadding: CGFloat = 24.0
    fileprivate static let headlineToMessagePadding: CGFloat = 4.0
    fileprivate static let actionsVerticalPadding: CGFloat = 20.0
    fileprivate static let actionButtonHeight: CGFloat = 56.0
    fileprivate static let imageHeight: CGFloat = 72.0
    
    // MARK: Private IBOutlets

    @IBOutlet fileprivate var imageView: UIImageView!
    @IBOutlet fileprivate var headline: UILabel!
    @IBOutlet fileprivate var message: UILabel!
    @IBOutlet fileprivate var confirmButton: UIButton!
    @IBOutlet fileprivate var defaultButton: UIButton!
    @IBOutlet fileprivate var closeButton: UIButton!
    @IBOutlet fileprivate var headlineTrailingConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var imageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate var imageViewHeightConstraint: NSLayoutConstraint!

    fileprivate var model: AlertModel!
    fileprivate var completion: ((AlertAction) -> Void)?
    
    // MARK: Public Class Functions
    
    public class func make(with model: AlertModel, completion: ((AlertAction) -> Void)?) -> AlertView {
        let bundle = Bundle(for: AlertView.self)
        let nib = UINib(nibName: String(describing: AlertView.self), bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! AlertView
        view.model = model
        view.completion = completion
        return view
    }
    
    public class func estimatedHeight(for width: CGFloat, model: AlertModel) -> CGFloat {
        let adjustedWidth = width - horizontalPadding
        let imageViewHeight: CGFloat = model.image?.size.height ?? 0
        var headlineHeight: CGFloat = 0.0
        var messageHeight: CGFloat = 0.0
        var interItemPadding: CGFloat = 0.0
        var actionsHeight: CGFloat = 0.0

        if let value = model.headline {
            let attributed = NSAttributedString(
                string: value,
                attributes: [.font: headlineFont()]
            )
            let trailingPadding = model.style == .default ? titleTrailingPadding : 0.0
            headlineHeight = attributed.heightForWidth(width: adjustedWidth - trailingPadding)
        }
        if let value = model.body {
            let attributed = NSAttributedString(
                string: value,
                attributes: [.font: messageFont()]
            )
            messageHeight = attributed.heightForWidth(width: adjustedWidth)
        }
        if model.headline != nil && model.body != nil {
            interItemPadding += headlineToMessagePadding
        }
        if model.actions.count > 1 {
            interItemPadding += actionsVerticalPadding
        }
        model.actions.forEach({ _ in actionsHeight += actionButtonHeight })
        let topPadding = model.dismissable ? topToHeadlingPadding : dismissableHeadlingPadding
        return messageToActionsPadding +
            actionsToBottomPadding +
            actionsHeight +
            imageViewHeight +
            headlineHeight +
            messageHeight +
            interItemPadding +
            topPadding
    }
    
    public class func headlineFont() -> UIFont {
        let font = Font(.branded(.montserratRegular), size: .custom(20.0))
        return font.result
    }
    
    public class func messageFont() -> UIFont {
        let font = Font(.branded(.montserratRegular), size: .custom(17.0))
        return font.result
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        apply(model: model)
    }
    
    public func registerForNotifications() {
        NotificationCenter.when(.UIApplicationDidEnterBackground) { [weak self] _ in
            guard let self = self else { return }
            self.teardown()
        }
    }
    
    // MARK: Private
    
    fileprivate func apply(model: AlertModel) {
        headline.isHidden = model.headline == nil
        message.isHidden = model.body == nil
        headline.text = model.headline
        message.text = model.body
        if let image = model.image {
            imageView.image = image
            imageViewHeightConstraint.constant = image.size.height
            imageViewWidthConstraint.constant = image.size.width
        }
        confirmButton.isHidden = model.actions.contains(where: { $0.style == .confirm }) == false
        defaultButton.isHidden = model.actions.contains(where: { $0.style == .default }) == false
        layer.cornerRadius = 8.0
        closeButton.tintColor = .gray4
        closeButton.isHidden = model.style == .sheet
        if closeButton.isHidden && headlineTrailingConstraint.isActive {
            NSLayoutConstraint.deactivate([headlineTrailingConstraint])
        }
        model.actions.forEach { action in
            switch action.style {
            case .confirm:
                let font = Font(.branded(.montserratSemiBold), size: .custom(20.0)).result
                let attributedTitle = NSAttributedString(
                    string: action.title,
                    attributes: [.font: font,
                                 .foregroundColor: #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)]
                )
                confirmButton.setAttributedTitle(attributedTitle, for: .normal)
            case .default:
                let font = Font(.branded(.montserratSemiBold), size: .custom(20.0)).result
                let attributedTitle = NSAttributedString(
                    string: action.title,
                    attributes: [.font: font,
                                 .foregroundColor: #colorLiteral(red: 0.06274509804, green: 0.6784313725, blue: 0.8941176471, alpha: 1)]
                )
                defaultButton.setAttributedTitle(attributedTitle, for: .normal)
            case .dismiss:
                break
            }
        }
        [confirmButton, defaultButton].forEach({ $0?.layer.cornerRadius = 4.0 })
        
        defaultButton.layer.borderColor = #colorLiteral(red: 0.06274509804, green: 0.6784313725, blue: 0.8941176471, alpha: 1)
        defaultButton.layer.borderWidth = 1.0
        confirmButton.backgroundColor = #colorLiteral(red: 0.06274509804, green: 0.6784313725, blue: 0.8941176471, alpha: 1)
    }
    
    fileprivate func teardown(with selectedAction: AlertAction? = nil) {
        UIView.animateKeyframes(withDuration: 0.3, delay: 0.0, options: .calculationModeCubic, animations: {
            UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0.1, animations: {
                self.alpha = 0.0
                self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            })
            UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.2, animations: {
                self.dimmingView.alpha = 0.0
                switch self.model.style {
                case .default:
                    break
                case .sheet:
                    guard let window = UIApplication.shared.keyWindow else { return }
                    self.frame = self.frame.offsetBy(dx: 0.0, dy: window.bounds.maxY)
                }
            })
        }, completion: { [weak self] _ in
            guard let this = self else { return }
            this.dimmingView.removeFromSuperview()
            this.removeFromSuperview()
            if let action = selectedAction {
                this.completion?(action)
            }
        })
    }
    
    @objc func dismiss() {
        guard model.dismissable == true else { return }
        let dismiss = model.actions.filter({ $0.style == .dismiss }).first
        teardown(with: dismiss)
    }
    
    // MARK: Actions
    
    @IBAction func confirmButtonTapped(_ sender: UIButton) {
        guard let confirm = model.actions.filter({ $0.style == .confirm }).first else { return }
        teardown(with: confirm)
    }
    
    @IBAction func defaultButtonTapped(_ sender: UIButton) {
        guard let action = model.actions.filter({ $0.style == .default }).first else { return }
        teardown(with: action)
    }
    
    @IBAction func dismissButtonTapped(_ sender: UIButton) {
        teardown()
    }
    
    // MARK: Public
    
    public func show() {
        switch model.style {
        case .default:
            presentDefaultView()
        case .sheet:
            presentSheetView()
        }
        registerForNotifications()
    }
    
    fileprivate func presentDefaultView() {
        guard let window = UIApplication.shared.keyWindow else { return }
        alpha = 0.0
        let width = window.bounds.width - AlertView.horizontalOffset
        let height = AlertView.estimatedHeight(
            for: width,
            model: model
        )
        frame = CGRect(
            origin: frame.origin,
            size: .init(
                width: width,
                height: height
            )
        )
        center = window.center
        transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        window.addSubview(dimmingView)
        window.addSubview(self)
        
        UIView.animateKeyframes(withDuration: 0.4, delay: 0.0, options: .calculationModeCubic, animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.1, animations: {
                self.dimmingView.alpha = 0.4
            })
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.2, animations: {
                self.alpha = 1.0
                self.transform = .identity
            })
        }, completion: nil)
    }
    
    fileprivate func presentSheetView() {
        guard let window = UIApplication.shared.keyWindow else { return }
        alpha = 0.0
        let width = window.bounds.width - AlertView.horizontalOffset
        let height = AlertView.estimatedHeight(
            for: width,
            model: model
        )
        let start = CGPoint(
            x: window.bounds.midX - (width / 2.0),
            y: window.bounds.maxY
        )
        frame = CGRect(
            origin: start,
            size: .init(
                width: width,
                height: height
            )
        )
        window.addSubview(dimmingView)
        window.addSubview(self)
        
        transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        UIView.animateKeyframes(withDuration: 0.4, delay: 0.0, options: .calculationModeCubic, animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.1, animations: {
                self.dimmingView.alpha = 0.4
            })
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.2, animations: {
                self.alpha = 1.0
                self.transform = .identity
                self.frame.origin = CGPoint(
                    x: self.frame.origin.x,
                    y: window.frame.maxY - height - AlertView.sheetBottomPadding
                )
            })
        }, completion: nil)
    }
    
    fileprivate lazy var dimmingView: UIView = {
        let dimming = UIView(frame: UIScreen.main.bounds)
        dimming.backgroundColor = .black
        dimming.alpha = 0.0
        dimming.isAccessibilityElement = true
        dimming.accessibilityTraits = UIAccessibilityTraitButton
        dimming.accessibilityHint = NSLocalizedString(
            "Double tap to close",
            comment: "Dimmed background behind a modal alert. Double tap to close."
        )
        dimming.isUserInteractionEnabled = true
        dimming.addGestureRecognizer(dismissTapGesture)
        return dimming
    }()
    
    fileprivate lazy var dismissTapGesture: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        return tap
    }()
    
}
