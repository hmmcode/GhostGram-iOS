import Foundation
import UIKit

/// Glass 👻 badge shown next to the name of GhostGram users in the profile header.
/// Tapping it opens a bottom sheet, like collectible gift badges do.
final class GhostGlassBadgeView: UIControl {
    static let size = CGSize(width: 24.0, height: 24.0)

    private let blurView: UIVisualEffectView
    private let tintLayer = CALayer()
    private let ringLayer = CAGradientLayer()
    private let ringMask = CAShapeLayer()
    private let glyphLabel = UILabel()

    override init(frame: CGRect) {
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        super.init(frame: frame)

        self.blurView.isUserInteractionEnabled = false
        self.blurView.clipsToBounds = true
        self.addSubview(self.blurView)

        self.tintLayer.backgroundColor = UIColor(red: 0.55, green: 0.36, blue: 1.0, alpha: 0.22).cgColor
        self.blurView.contentView.layer.addSublayer(self.tintLayer)

        self.ringLayer.colors = [
            UIColor(red: 0.62, green: 0.40, blue: 1.0, alpha: 1.0).cgColor,
            UIColor(red: 0.25, green: 0.85, blue: 1.0, alpha: 1.0).cgColor,
            UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9).cgColor,
            UIColor(red: 0.62, green: 0.40, blue: 1.0, alpha: 1.0).cgColor
        ]
        self.ringLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        self.ringLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.ringMask.fillColor = UIColor.clear.cgColor
        self.ringMask.strokeColor = UIColor.black.cgColor
        self.ringMask.lineWidth = frame.width > 40.0 ? 3.0 : 1.5
        self.ringLayer.mask = self.ringMask
        self.layer.addSublayer(self.ringLayer)

        self.glyphLabel.text = "👻"
        self.glyphLabel.font = UIFont.systemFont(ofSize: frame.width > 40.0 ? frame.width * 0.55 : 13.0)
        self.glyphLabel.textAlignment = .center
        self.glyphLabel.isUserInteractionEnabled = false
        self.addSubview(self.glyphLabel)

        // Slow "liquid" shimmer of the ring.
        let shimmer = CABasicAnimation(keyPath: "startPoint")
        shimmer.fromValue = CGPoint(x: 0.0, y: 0.0)
        shimmer.toValue = CGPoint(x: 1.0, y: 0.0)
        shimmer.duration = 2.4
        shimmer.autoreverses = true
        shimmer.repeatCount = .infinity
        shimmer.isRemovedOnCompletion = false
        self.ringLayer.add(shimmer, forKey: "ghostShimmer")
        let shimmerEnd = CABasicAnimation(keyPath: "endPoint")
        shimmerEnd.fromValue = CGPoint(x: 1.0, y: 1.0)
        shimmerEnd.toValue = CGPoint(x: 0.0, y: 1.0)
        shimmerEnd.duration = 2.4
        shimmerEnd.autoreverses = true
        shimmerEnd.repeatCount = .infinity
        shimmerEnd.isRemovedOnCompletion = false
        self.ringLayer.add(shimmerEnd, forKey: "ghostShimmerEnd")

        self.addTarget(self, action: #selector(self.tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.bounds
        self.blurView.frame = bounds
        self.blurView.layer.cornerRadius = bounds.height / 2.0
        self.tintLayer.frame = bounds
        self.ringLayer.frame = bounds
        self.ringMask.frame = bounds
        let inset = self.ringMask.lineWidth / 2.0
        self.ringMask.path = UIBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset)).cgPath
        self.glyphLabel.frame = bounds
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(dx: -8.0, dy: -8.0).contains(point)
    }

    @objc private func tapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard var presenter = self.window?.rootViewController else {
            return
        }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        let sheet = GhostBadgeSheetController()
        sheet.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheetController = sheet.sheetPresentationController {
            sheetController.detents = [.medium()]
            sheetController.prefersGrabberVisible = true
            sheetController.preferredCornerRadius = 32.0
        }
        presenter.present(sheet, animated: true, completion: nil)
    }
}

/// Bottom sheet opened from the 👻 badge, laid out like the collectible gift sheet:
/// big glass badge, title, description, info table and a button.
final class GhostBadgeSheetController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear

        let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        background.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(background)

        let glowView = UIView()
        glowView.translatesAutoresizingMaskIntoConstraints = false
        glowView.isUserInteractionEnabled = false
        glowView.backgroundColor = UIColor(red: 0.55, green: 0.36, blue: 1.0, alpha: 0.35)
        glowView.layer.cornerRadius = 90.0
        self.view.addSubview(glowView)
        let glowBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        glowBlur.translatesAutoresizingMaskIntoConstraints = false
        glowBlur.isUserInteractionEnabled = false
        self.view.addSubview(glowBlur)

        let badge = GhostGlassBadgeView(frame: CGRect(origin: .zero, size: CGSize(width: 96.0, height: 96.0)))
        badge.isUserInteractionEnabled = false
        badge.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(badge)

        let titleLabel = UILabel()
        titleLabel.text = "Пользователь GhostGram"
        titleLabel.font = UIFont.systemFont(ofSize: 24.0, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Этот человек сидит в GhostGram — клиенте с режимом призрака, удалёнками и историей правок."
        subtitleLabel.font = UIFont.systemFont(ofSize: 15.0)
        subtitleLabel.textColor = UIColor(white: 1.0, alpha: 0.7)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let table = UIStackView(arrangedSubviews: [
            GhostBadgeSheetController.row("Значок", "👻 Призрак"),
            GhostBadgeSheetController.row("Редкость", "Только для своих"),
            GhostBadgeSheetController.row("Видят", "Пользователи GhostGram")
        ])
        table.axis = .vertical
        table.spacing = 1.0
        table.backgroundColor = UIColor(white: 1.0, alpha: 0.12)
        table.layer.cornerRadius = 14.0
        table.layer.borderWidth = 1.0
        table.layer.borderColor = UIColor(white: 1.0, alpha: 0.12).cgColor
        table.clipsToBounds = true

        let button = UIButton(type: .system)
        button.setTitle("Понятно", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        button.backgroundColor = UIColor(red: 0.55, green: 0.36, blue: 1.0, alpha: 1.0)
        button.layer.cornerRadius = 14.0
        button.addTarget(self, action: #selector(self.close), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, table, button])
        stack.axis = .vertical
        stack.spacing = 14.0
        stack.setCustomSpacing(8.0, after: titleLabel)
        stack.setCustomSpacing(20.0, after: table)
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stack)

        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: self.view.topAnchor),
            background.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            background.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            badge.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 36.0),
            badge.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            badge.widthAnchor.constraint(equalToConstant: 96.0),
            badge.heightAnchor.constraint(equalToConstant: 96.0),
            glowView.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            glowView.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            glowView.widthAnchor.constraint(equalToConstant: 180.0),
            glowView.heightAnchor.constraint(equalToConstant: 180.0),
            glowBlur.topAnchor.constraint(equalTo: self.view.topAnchor),
            glowBlur.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            glowBlur.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            glowBlur.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: 60.0),
            stack.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 20.0),
            stack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20.0),
            stack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20.0),
            button.heightAnchor.constraint(equalToConstant: 50.0)
        ])
    }

    private static func row(_ title: String, _ value: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.08, alpha: 0.9)
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 15.0)
        titleLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 15.0, weight: .medium)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 44.0),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14.0),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14.0),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12.0)
        ])
        return container
    }

    @objc private func close() {
        self.dismiss(animated: true, completion: nil)
    }
}
