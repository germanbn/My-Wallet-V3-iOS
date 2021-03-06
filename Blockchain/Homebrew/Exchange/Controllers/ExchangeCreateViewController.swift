//
//  ExchangeCreateViewController.swift
//  Blockchain
//
//  Created by kevinwu on 8/15/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformUIKit
import SafariServices
import RxSwift

protocol ExchangeCreateDelegate: NumberKeypadViewDelegate {
    func onViewDidLoad()
    func onViewWillAppear()
    func onDisplayRatesTapped()
    func onHideRatesTapped()
    func onKeypadVisibilityUpdated(_ visibility: Visibility, animated: Bool)
    func onDisplayInputTypeTapped()
    func onExchangeButtonTapped()
    func onSwapButtonTapped()
}

// swiftlint:disable line_length
class ExchangeCreateViewController: UIViewController {
    
    // MARK: Private Static Properties
    
    static let isLargerThan5S: Bool = Constants.Booleans.IsUsingScreenSizeLargerThan5s
    static let primaryFontName: String = Constants.FontNames.montserratMedium
    static let primaryFontSize: CGFloat = isLargerThan5S ? 64.0 : Constants.FontSizes.Gigantic
    static let secondaryFontName: String = Constants.FontNames.montserratRegular
    static let secondaryFontSize: CGFloat = Constants.FontSizes.Huge

    // MARK: - IBOutlets

    @IBOutlet private var tradingPairView: TradingPairView!
    @IBOutlet private var numberKeypadView: NumberKeypadView!

    // Label to be updated when amount is being typed in
    @IBOutlet private var primaryAmountLabel: UILabel!

    // Amount being typed in converted to input crypto or input fiat
    @IBOutlet private var secondaryAmountLabel: UILabel!
    
    // Label that is hidden unlesss the user attempts to submit
    // an exchange that is below the minimum value or above the max.
    @IBOutlet private var errorLabel: ActionableLabel!
    fileprivate var trigger: ActionableTrigger?

    @IBOutlet private var hideRatesButton: UIButton!
    @IBOutlet private var conversionRatesView: ConversionRatesView!
    @IBOutlet private var fixToggleButton: UIButton!
    @IBOutlet private var conversionView: UIView!
    @IBOutlet private var conversionTitleLabel: UILabel!
    @IBOutlet private var exchangeButton: UIButton!
    @IBOutlet private var exchangeButtonBottomConstraint: NSLayoutConstraint!
    
    enum PresentationUpdate {
        case wiggleInputLabels
        case wigglePrimaryLabel
        case updatePrimaryLabel(NSAttributedString?)
        case updateSecondaryLabel(String?)
        case updateErrorLabel(String)
        case actionableErrorLabelTrigger(ActionableTrigger)
        case updateRateLabels(first: String, second: String, third: String)
        case keypadVisibility(Visibility, animated: Bool)
        case conversionRatesView(Visibility, animated: Bool)
        case loadingIndicator(Visibility)
    }
    
    enum ViewUpdate: Update {
        case conversionTitleLabel(Visibility)
        case conversionView(Visibility)
        case exchangeButton(Visibility)
        case ratesChevron(Visibility)
        case errorLabel(Visibility)
    }
    
    enum TransitionUpdate: Transition {
        case primaryLabelTextColor(UIColor)
    }

    // MARK: Public Properties

    weak var delegate: ExchangeCreateDelegate?

    // MARK: Private Properties

    fileprivate var presenter: ExchangeCreatePresenter!
    fileprivate var dependencies: ExchangeDependencies = ExchangeServices()
    fileprivate var assetAccountListPresenter: ExchangeAssetAccountListPresenter!
    fileprivate var fromAccount: AssetAccount!
    fileprivate var toAccount: AssetAccount!
    fileprivate var disposable: Disposable?

    // MARK: Lifecycle
    
    deinit {
        disposable?.dispose()
        disposable = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LocalizationConstants.Swap.swap
        dependenciesSetup()
        viewsSetup()
        delegate?.onViewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        delegate?.onViewWillAppear()
    }

    // MARK: Private

    private func viewsSetup() {
        [primaryAmountLabel, secondaryAmountLabel].forEach {
            $0?.textColor = UIColor.brandPrimary
        }
        
        errorLabel.font = UIFont(name: Constants.FontNames.montserratRegular, size: Constants.FontSizes.ExtraExtraSmall)
        
        [conversionView, hideRatesButton].forEach {
            addStyleToView($0)
        }

        tradingPairView.delegate = self
        errorLabel.delegate = self

        exchangeButton.layer.cornerRadius = Constants.Measurements.buttonCornerRadius

        exchangeButton.setTitle(LocalizationConstants.Swap.exchange, for: .normal)
        
        let isAboveSE = UIDevice.current.type.isAbove(.iPhoneSE)
        exchangeButtonBottomConstraint.constant = isAboveSE ? 16.0 : 0.0
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    fileprivate func dependenciesSetup() {
        fromAccount = dependencies.assetAccountRepository.defaultAccount(for: .bitcoin)
        toAccount = dependencies.assetAccountRepository.defaultAccount(for: .ethereum)
        
        // DEBUG - ideally add an .empty state for a blank/loading state for MarketsModel here.
        let interactor = ExchangeCreateInteractor(
            dependencies: dependencies,
            model: MarketsModel(
                marketPair: MarketPair(fromAccount: fromAccount, toAccount: toAccount),
                fiatCurrencyCode: BlockchainSettings.sharedAppInstance().fiatCurrencyCode ?? "USD",
                fiatCurrencySymbol: BlockchainSettings.App.shared.fiatCurrencySymbol,
                fix: .baseInFiat,
                volume: "0"
            )
        )
        assetAccountListPresenter = ExchangeAssetAccountListPresenter(view: self)
        numberKeypadView.delegate = self
        presenter = ExchangeCreatePresenter(interactor: interactor)
        presenter.interface = self
        interactor.output = presenter
        delegate = presenter
    }
    
    fileprivate func presentURL(_ url: URL) {
        let viewController = SFSafariViewController(url: url)
        guard let controller = AppCoordinator.shared.tabControllerManager.tabViewController else { return }
        viewController.modalPresentationStyle = .overCurrentContext
        controller.present(viewController, animated: true, completion: nil)
    }
    
    // MARK: - IBActions

    @IBAction func fixToggleButtonTapped(_ sender: UIButton) {
        let imageToggle = (fixToggleButton.currentImage == #imageLiteral(resourceName: "icon-toggle-left")) ? #imageLiteral(resourceName: "icon-toggle-right") : #imageLiteral(resourceName: "icon-toggle-left")
        fixToggleButton.setImage(imageToggle, for: .normal)
        presenter.onToggleFixTapped()
    }

    @IBAction private func ratesViewTapped(_ sender: UITapGestureRecognizer) {
        delegate?.onDisplayRatesTapped()
    }
    
    @IBAction private func rateButtonTapped(_ sender: UIButton) {
        delegate?.onDisplayRatesTapped()
    }
    
    @IBAction private func hideRatesButtonTapped(_ sender: UIButton) {
        delegate?.onHideRatesTapped()
    }
    
    @IBAction private func displayInputTypeTapped(_ sender: Any) {
        delegate?.onDisplayInputTypeTapped()
    }
    
    @IBAction private func exchangeButtonTapped(_ sender: Any) {
        delegate?.onExchangeButtonTapped()
    }
}

// MARK: - Styling
extension ExchangeCreateViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    private func addStyleToView(_ viewToEdit: UIView) {
        viewToEdit.layer.cornerRadius = 4.0
        viewToEdit.layer.borderWidth = 1.0
        viewToEdit.layer.borderColor = UIColor.brandPrimary.cgColor
    }
}

extension ExchangeCreateViewController: NumberKeypadViewDelegate {
    func onDelimiterTapped(value: String) {
        delegate?.onDelimiterTapped(value: value)
    }
    
    func onAddInputTapped(value: String) {
        delegate?.onAddInputTapped(value: value)
    }

    func onBackspaceTapped() {
        delegate?.onBackspaceTapped()
    }
}

extension ExchangeCreateViewController: ExchangeCreateInterface {
    func showTiers() {
        disposable = KYCTiersViewController.routeToTiers(
            fromViewController: self
        )
    }
    
    func apply(transitionPresentation: TransitionPresentationUpdate<ExchangeCreateInterface.TransitionUpdate>) {
        transitionPresentation.transitionType.perform(with: view, animations: { [weak self] in
            guard let this = self else { return }
            transitionPresentation.transitions.forEach({ this.apply(transition: $0) })
        })
    }
    
    func apply(transitionUpdateGroup: ExchangeCreateInterface.TransitionUpdateGroup) {
        let completion: () -> Void = {
            transitionUpdateGroup.finish()
        }
        transitionUpdateGroup.preparations.forEach({ apply(transition: $0) })
        transitionUpdateGroup.transitionType.perform(with: view, animations: { [weak self] in
            transitionUpdateGroup.transitions.forEach({ self?.apply(transition: $0) })
        }, completion: completion)
    }
    
    func apply(presentationUpdateGroup: ExchangeCreateInterface.PresentationUpdateGroup) {
        let completion: () -> Void = {
            presentationUpdateGroup.finish()
        }
        presentationUpdateGroup.preparations.forEach({ apply(update: $0) })
        presentationUpdateGroup.animationType.perform(animations: { [weak self] in
            presentationUpdateGroup.animations.forEach({ self?.apply(update: $0) })
        }, completion: completion)
    }
    
    func apply(presentationUpdates: [ExchangeCreateInterface.PresentationUpdate]) {
        presentationUpdates.forEach({ apply(presentationUpdate: $0) })
    }
    
    func apply(animatedUpdate: ExchangeCreateInterface.AnimatedUpdate) {
        animatedUpdate.animationType.perform(animations: { [weak self] in
            guard let this = self else { return }
            animatedUpdate.animations.forEach({ this.apply(update: $0) })
        })
    }
    
    func apply(viewUpdates: [ExchangeCreateInterface.ViewUpdate]) {
        viewUpdates.forEach({ apply(update: $0) })
    }
    
    func apply(transition: TransitionUpdate) {
        switch transition {
        case .primaryLabelTextColor(let color):
            primaryAmountLabel.textColor = color
        }
    }
    
    func apply(update: ViewUpdate) {
        switch update {
        case .conversionTitleLabel(let visibility):
            conversionTitleLabel.alpha = visibility.defaultAlpha
        case .conversionView(let visibility):
            conversionView.alpha = visibility.defaultAlpha
        case .exchangeButton(let visibility):
            exchangeButton.alpha = visibility.defaultAlpha
        case .ratesChevron(let visibility):
            hideRatesButton.alpha = visibility.defaultAlpha
        case .errorLabel(let visibility):
            errorLabel.alpha = visibility.defaultAlpha
        }
    }
    
    func apply(presentationUpdate: PresentationUpdate) {
        switch presentationUpdate {
        case .loadingIndicator(let visibility):
            switch visibility {
            case .visible:
                LoadingViewPresenter.shared.showBusyView(
                    withLoadingText: LocalizationConstants.Exchange.confirming
                )
            case .hidden:
                LoadingViewPresenter.shared.hideBusyView()
            default:
                Logger.shared.warning("Visibility not handled")
            }
        case .conversionRatesView(let visibility, animated: let animated):
            conversionRatesView.updateVisibility(visibility, animated: animated)
        case .keypadVisibility(let visibility, animated: let animated):
            numberKeypadView.updateKeypadVisibility(visibility, animated: animated) { [weak self] in
                guard let this = self else { return }
                this.delegate?.onKeypadVisibilityUpdated(visibility, animated: animated)
            }
        case .updatePrimaryLabel(let value):
            primaryAmountLabel.attributedText = value
        case .updateSecondaryLabel(let value):
            secondaryAmountLabel.text = value
        case .wiggleInputLabels:
            primaryAmountLabel.wiggle()
            secondaryAmountLabel.wiggle()
        case .wigglePrimaryLabel:
            primaryAmountLabel.wiggle()
        case .updateRateLabels(first: let first, second: let second, third: let third):
            conversionTitleLabel.text = first
            conversionRatesView.apply(baseToCounter: first, baseToFiat: second, counterToFiat: third)
        case .updateErrorLabel(let value):
            errorLabel.text = value
        case .actionableErrorLabelTrigger(let trigger):
            self.trigger = trigger
            let primary = NSMutableAttributedString(
                string: trigger.primaryString,
                attributes: useErrorTierLimitAttributes()
            )

            let CTA = NSAttributedString(
                string: " " + trigger.callToAction,
                attributes: useErrorTierLimitActionAttributes()
            )

            primary.append(CTA)

            if let secondary = trigger.secondaryString {
                let trailing = NSMutableAttributedString(
                    string: " " + secondary,
                    attributes: useErrorTierLimitAttributes()
                )
                primary.append(trailing)
            }

            errorLabel.attributedText = primary
        }
    }

    fileprivate func useErrorTierLimitAttributes() -> [NSAttributedString.Key: Any] {
        let fontName = Constants.FontNames.montserratRegular
        let font = UIFont(name: fontName, size: 13.0) ?? UIFont.systemFont(ofSize: 13.0)
        return [.font: font,
                .foregroundColor: errorLabel.textColor]
    }

    fileprivate func useErrorTierLimitActionAttributes() -> [NSAttributedString.Key: Any] {
        let fontName = Constants.FontNames.montserratRegular
        let font = UIFont(name: fontName, size: 13.0) ?? UIFont.systemFont(ofSize: 13.0)
        return [.font: font,
                .foregroundColor: UIColor.brandSecondary]
    }

    func updateTradingPairView(pair: TradingPair, fix: Fix) {
        let fromAsset = pair.from
        let toAsset = pair.to

        let isUsingBase = fix == .base || fix == .baseInFiat
        let leftVisibility: TradingPairView.ViewUpdate = .leftStatusVisibility(isUsingBase ? .visible : .hidden)
        let rightVisibility: TradingPairView.ViewUpdate = .rightStatusVisibility(isUsingBase ? .hidden : .visible)

        let transitionUpdate = TradingPairView.TradingTransitionUpdate(
            transitions: [
                .images(left: fromAsset.brandImage, right: toAsset.brandImage),
                .titles(left: "", right: "")
            ],
            transition: .crossFade(duration: 0.2)
        )

        let presentationUpdate = TradingPairView.TradingPresentationUpdate(
            animations: [
                .backgroundColors(left: fromAsset.brandColor, right: toAsset.brandColor),
                leftVisibility,
                rightVisibility,
                .statusTintColor(#colorLiteral(red: 0.01176470588, green: 0.662745098, blue: 0.4470588235, alpha: 1)),
                .swapTintColor(#colorLiteral(red: 0, green: 0.2901960784, blue: 0.4862745098, alpha: 1)),
                .titleColor(#colorLiteral(red: 0, green: 0.2901960784, blue: 0.4862745098, alpha: 1))
            ],
            animation: .none
        )
        let model = TradingPairView.Model(
            transitionUpdate: transitionUpdate,
            presentationUpdate: presentationUpdate
        )
        tradingPairView.apply(model: model)
    }

    func updateTradingPairViewValues(left: String, right: String) {
        let transitionUpdate = TradingPairView.TradingTransitionUpdate(
            transitions: [.titles(left: left, right: right)],
            transition: .none
        )
        tradingPairView.apply(transitionUpdate: transitionUpdate)
    }
    
    func exchangeButtonEnabled(_ enabled: Bool) {
        exchangeButton.isEnabled = enabled
    }

    func isShowingConversionRatesView() -> Bool {
        return conversionRatesView.alpha == 1
    }

    func isExchangeButtonEnabled() -> Bool {
        return exchangeButton.isEnabled
    }
    
    func showSummary(orderTransaction: OrderTransaction, conversion: Conversion) {
        let model = ExchangeDetailPageModel(type: .confirm(orderTransaction, conversion))
        let confirmController = ExchangeDetailViewController.make(with: model, dependencies: self.dependencies)
        navigationController?.pushViewController(confirmController, animated: true)
    }
}

// MARK: - TradingPairViewDelegate

extension ExchangeCreateViewController: TradingPairViewDelegate {
    func onLeftButtonTapped(_ view: TradingPairView, title: String) {
        assetAccountListPresenter.presentPicker(excludingAccount: fromAccount, for: .exchanging)
    }

    func onRightButtonTapped(_ view: TradingPairView, title: String) {
        assetAccountListPresenter.presentPicker(excludingAccount: toAccount, for: .receiving)
    }

    func onSwapButtonTapped(_ view: TradingPairView) {
        // TICKET: https://blockchain.atlassian.net/browse/IOS-1350
    }
}

// MARK: - ExchangeAssetAccountListView

extension ExchangeCreateViewController: ExchangeAssetAccountListView {
    func showPicker(for assetAccounts: [AssetAccount], action: ExchangeAction) {
        let actionSheetController = UIAlertController(title: action.title, message: nil, preferredStyle: .actionSheet)

        // Insert actions
        assetAccounts.forEach { account in
            let alertAction = UIAlertAction(title: account.name, style: .default, handler: { [unowned self] _ in
                Logger.shared.debug("Selected account titled: '\(account.name)' of type: '\(account.address.assetType.symbol)'")
                
                /// Note: Users should not be able to exchange between
                /// accounts with the same assetType.
                switch action {
                case .exchanging:
                    if account.address.assetType == self.toAccount.address.assetType {
                        self.toAccount = self.fromAccount
                    }
                    
                    self.fromAccount = account
                case .receiving:
                    if account.address.assetType == self.fromAccount.address.assetType {
                        self.fromAccount = self.toAccount
                    }
                    self.toAccount = account
                }
                self.onTradingPairChanged()
            })
            actionSheetController.addAction(alertAction)
        }
        actionSheetController.addAction(
            UIAlertAction(title: LocalizationConstants.cancel, style: .cancel)
        )
        
        present(actionSheetController, animated: true)
    }

    private func onTradingPairChanged() {
        presenter.changeMarketPair(
            marketPair: MarketPair(
                fromAccount: fromAccount,
                toAccount: toAccount
            )
        )
    }
}

extension ExchangeCreateViewController: UIViewControllerTransitioningDelegate {
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ModalAnimator(operation: .dismiss, duration: 0.4)
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ModalAnimator(operation: .present, duration: 0.4)
    }
}

extension ExchangeCreateViewController: ActionableLabelDelegate {
    func targetRange(_ label: ActionableLabel) -> NSRange? {
        return trigger?.actionRange()
    }

    func actionRequestingExecution(label: ActionableLabel) {
        guard let trigger = trigger else { return }
        trigger.execute()
    }
}

extension ExchangeCreateViewController: NavigatableView {
    var leftCTATintColor: UIColor {
        return .white
    }
    
    var rightCTATintColor: UIColor {
        return .white
    }
    
    var leftNavControllerCTAType: NavigationCTAType {
        return .menu
    }
    
    var rightNavControllerCTAType: NavigationCTAType {
        return .help
    }
    
    var navigationDisplayMode: NavigationBarDisplayMode {
        return .dark
    }
    
    func navControllerRightBarButtonTapped(_ navController: UINavigationController) {
        guard let endpoint = URL(string: "https://blockchain.zendesk.com/") else { return }
        guard let url = URL.endpoint(
            endpoint,
            pathComponents: ["hc", "en-us", "requests", "new"],
            queryParameters: ["ticket_form_id" : "360000180551"]
            ) else { return }
        
        let orderHistory = BottomSheetAction(title: LocalizationConstants.Swap.orderHistory, metadata: .block({
            guard let root = UIApplication.shared.keyWindow?.rootViewController else {
                Logger.shared.error("No navigation controller found")
                return
            }
            let controller = ExchangeListViewController.make(with: self.dependencies)
            let navController = BaseNavigationController(rootViewController: controller)
            navController.modalTransitionStyle = .coverVertical
            root.present(navController, animated: true, completion: nil)
        }))
        let viewLimits = BottomSheetAction(title: LocalizationConstants.Swap.viewMySwapLimit, metadata: .block({
            _ = KYCTiersViewController.routeToTiers(fromViewController: self)
        }))
        let contactSupport = BottomSheetAction(title: LocalizationConstants.KYC.contactSupport, metadata: .url(url))
        let model = BottomSheet(
            title: LocalizationConstants.Swap.swapInfo,
            dismissalTitle: LocalizationConstants.Swap.close,
            actions: [orderHistory, contactSupport, viewLimits]
        )
        let sheet = BottomSheetView.make(with: model) { [weak self] action in
            guard let this = self else { return }
            guard let value = action.metadata else { return }
            
            switch value {
            case .url(let url):
                this.presentURL(url)
            case .block(let block):
                block()
            case .pop:
                this.navigationController?.popViewController(animated: true)
            case .dismiss:
                this.dismiss(animated: true, completion: nil)
            case .payload:
                break
            }
        }
        sheet.show()
    }
    
    func navControllerLeftBarButtonTapped(_ navController: UINavigationController) {
        AppCoordinator.shared.toggleSideMenu()
    }
}
