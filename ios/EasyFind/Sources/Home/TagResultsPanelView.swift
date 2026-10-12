import UIKit

/// 底部弹出的 Tag 清单面板（MoTo Tag 风格）。
///
/// 扫描到标签时从屏幕底部滑入，实时列出发现的标签（名称 + 信号强度）；
/// 点击某一项后回调 `onSelectTag`，由页面收起面板并进入测距态。
final class TagResultsPanelView: UIView, UITableViewDataSource, UITableViewDelegate {

    var onSelectTag: ((ScannedTag) -> Void)?

    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)

    private var tags: [ScannedTag] = []

    private static let cellID = "ScannedTagCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        backgroundColor = UIColor(white: 0.12, alpha: 1)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor(white: 1, alpha: 0.12)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ScannedTagCell.self, forCellReuseIdentifier: Self.cellID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    /// 更新发现列表（去重、按 RSSI 排序、最新时间在前），并刷新标题。
    func update(tags newTags: [ScannedTag]) {
        var merged: [String: ScannedTag] = [:]
        for tag in newTags {
            if let existing = merged[tag.address], existing.lastSeenAt >= tag.lastSeenAt {
                continue
            }
            merged[tag.address] = tag
        }
        tags = merged.values.sorted {
            if $0.rssi == $1.rssi { return $0.lastSeenAt > $1.lastSeenAt }
            return $0.rssi > $1.rssi
        }
        titleLabel.text = tags.isEmpty ? "正在扫描标签…" : "发现 \(tags.count) 个标签 · 点击开始测距"
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tags.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellID, for: indexPath) as! ScannedTagCell
        cell.configure(with: tags[indexPath.row])
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelectTag?(tags[indexPath.row])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        64
    }
}

/// 单个扫描结果行：名称 + 信号强度 + 测距提示。
private final class ScannedTagCell: UITableViewCell {

    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let rssiBar = RSSIBarsView()
    private let arrowLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .default

        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        addressLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        addressLabel.textColor = UIColor(white: 1, alpha: 0.5)
        addressLabel.translatesAutoresizingMaskIntoConstraints = false

        rssiBar.translatesAutoresizingMaskIntoConstraints = false

        arrowLabel.text = "›"
        arrowLabel.font = .systemFont(ofSize: 26, weight: .light)
        arrowLabel.textColor = UIColor(white: 1, alpha: 0.4)
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(nameLabel)
        contentView.addSubview(addressLabel)
        contentView.addSubview(rssiBar)
        contentView.addSubview(arrowLabel)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            addressLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            addressLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            rssiBar.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            rssiBar.trailingAnchor.constraint(equalTo: arrowLabel.leadingAnchor, constant: -14),
            rssiBar.widthAnchor.constraint(equalToConstant: 34),
            rssiBar.heightAnchor.constraint(equalToConstant: 18),

            arrowLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    func configure(with tag: ScannedTag) {
        nameLabel.text = tag.name
        addressLabel.text = tag.address.prefix(8) + "…"
        rssiBar.setRSSI(tag.rssi)
    }
}

/// RSSI 信号强度条（3~5 格，随强度点亮）。
private final class RSSIBarsView: UIView {
    private var bars: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        for _ in 0..<4 {
            let bar = UIView()
            bar.backgroundColor = UIColor(white: 1, alpha: 0.15)
            bar.layer.cornerRadius = 2
            bars.append(bar)
            addSubview(bar)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let spacing: CGFloat = 3
        let width = (bounds.width - spacing * 3) / 4
        let heights: [CGFloat] = [6, 10, 14, 18]
        for (i, bar) in bars.enumerated() {
            bar.frame = CGRect(
                x: CGFloat(i) * (width + spacing),
                y: bounds.height - heights[i],
                width: width,
                height: heights[i]
            )
        }
    }

    func setRSSI(_ rssi: Int) {
        let level: Int
        if rssi >= -60 { level = 4 }
        else if rssi >= -70 { level = 3 }
        else if rssi >= -80 { level = 2 }
        else if rssi >= -90 { level = 1 }
        else { level = 0 }

        for (i, bar) in bars.enumerated() {
            bar.backgroundColor = i < level
                ? UIColor(white: 1, alpha: 0.9)
                : UIColor(white: 1, alpha: 0.15)
        }
    }
}
