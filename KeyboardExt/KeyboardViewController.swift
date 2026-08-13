import UIKit
import Combine

/// Clavier système qui envoie les touches au Mac via le réseau local.
/// Nécessite « Autoriser l'accès complet » pour accéder au réseau.
final class KeyboardViewController: UIInputViewController {

    // MARK: - État

    private var connection: MessageConnection?
    private var cancellable: AnyCancellable?

    private var isShifted = false
    private var isSymbols = false
    private var cmd = false
    private var opt = false
    private var ctrl = false

    // MARK: - Vues

    private let statusLabel = UILabel()
    private let rootStack = UIStackView()
    private var charButtons: [KeyButton] = []
    private var shiftButton: KeyButton?
    private var symbolsButton: KeyButton?
    private var cmdButton: KeyButton?
    private var optButton: KeyButton?
    private var ctrlButton: KeyButton?

    // MARK: - Modèle des touches

    struct KeyModel {
        var letters: String
        var lettersShifted: String
        var symbols: String
        var symbolsShifted: String
    }

    enum KeySpec {
        case char(KeyModel)
        case tab, delete, shift, symbols, space, enter, globe, cmd, opt, ctrl
        case arrow(SpecialKey)
    }

    private func width(_ spec: KeySpec) -> CGFloat {
        switch spec {
        case .char: return 1
        case .tab, .delete: return 1.3
        case .shift, .symbols: return 1.4
        case .globe, .cmd, .opt, .ctrl, .arrow: return 1.4
        case .enter: return 2
        case .space: return 4
        }
    }

    /// Symboles associés aux touches, rangée par rangée. Ils ne dépendent pas
    /// de la disposition des lettres : on les applique dans l'ordre.
    private static let symbolRows: [[(String, String)]] = [
        [("1", "!"), ("2", "@"), ("3", "#"), ("4", "$"), ("5", "%"),
         ("6", "^"), ("7", "&"), ("8", "*"), ("9", "("), ("0", ")")],
        [("-", "_"), ("/", "\\"), (":", ";"), ("(", ")"), ("$", "€"),
         ("&", "£"), ("@", "#"), ("\"", "'"), (".", ","), ("«", "»")],
        [(",", "<"), ("?", "!"), ("!", "¡"), ("'", "`"), ("[", "{"),
         ("]", "}"), ("|", "~")]
    ]

    private var rows: [[KeySpec]] {
        let letterRows = KeyboardStyle.current.rows

        var result: [[KeySpec]] = []
        for (index, letters) in letterRows.enumerated() {
            let symbols = Self.symbolRows.indices.contains(index) ? Self.symbolRows[index] : []

            var row: [KeySpec] = letters.enumerated().map { position, letter in
                let symbol = symbols.indices.contains(position) ? symbols[position] : (letter, letter)
                return .char(KeyModel(letters: letter,
                                      lettersShifted: letter.uppercased(),
                                      symbols: symbol.0,
                                      symbolsShifted: symbol.1))
            }

            // Touches de bord, ajoutées après coup pour rester alignées sur
            // le nombre réel de lettres de la disposition choisie.
            switch index {
            case 1:
                row.insert(.tab, at: 0)
                row.append(.delete)
            case 2:
                row.insert(.symbols, at: 0)
                row.insert(.shift, at: 1)
                row.append(.enter)
            default:
                break
            }
            result.append(row)
        }

        result.append([.globe, .cmd, .opt, .ctrl, .space, .arrow(.left), .arrow(.right)])
        return result
    }

    // MARK: - Cycle de vie

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray5

        setupConnection()
        setupUI()
        rebuildTitles()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Sans « accès complet », l'extension n'a pas le droit d'ouvrir le
        // réseau : inutile de tenter la connexion.
        guard hasFullAccess else {
            refreshStatus()
            return
        }
        connection?.start()
        refreshStatus()
    }

    // La connexion n'est volontairement PAS coupée quand le clavier se cache :
    // iOS garde le processus de l'extension en vie quelques instants, et
    // reconstruire la session MultipeerConnectivity coûte plusieurs secondes
    // avant que la première touche parte.

    deinit {
        connection?.stop()
    }

    // MARK: - Connexion

    private func setupConnection() {
        let name = UIDevice.current.name.isEmpty ? "iPhone" : UIDevice.current.name
        let connection = MessageConnection(displayName: "\(name) (Clavier)", isHost: false)
        self.connection = connection

        // L'appairage se fait dans l'app ; l'extension réutilise le jeton
        // via le trousseau partagé et se connecte sans rien demander.
        cancellable = connection.$isConnected
            .combineLatest(connection.$pairingState)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatus() }
    }

    private var currentFlags: Int {
        var flags = 0
        if cmd  { flags |= ModFlag.command }
        if opt  { flags |= ModFlag.option }
        if ctrl { flags |= ModFlag.control }
        return flags
    }

    private func send(_ message: Message) {
        connection?.send(message)
    }

    /// Touche nommée : keycode stable, indépendant de la disposition.
    private func sendKey(_ key: SpecialKey) {
        send(.specialKey(key, flags: currentFlags))
        clearModifiers()
    }

    /// Caractère : c'est le Mac qui choisit la touche physique d'après sa
    /// propre disposition.
    private func sendChar(_ char: Character) {
        send(.character(char, flags: currentFlags))
        clearModifiers()
    }

    /// Les modificateurs ne valent que pour la frappe suivante.
    private func clearModifiers() {
        guard cmd || opt || ctrl else { return }
        cmd = false
        opt = false
        ctrl = false
        rebuildTitles()
    }

    // MARK: - UI

    private func setupUI() {
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel

        rootStack.axis = .vertical
        rootStack.spacing = 6
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            rootStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 6),
            rootStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -6),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6)
        ])

        statusLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        rootStack.addArrangedSubview(statusLabel)

        for row in rows {
            buildRow(row)
        }
    }

    private func buildRow(_ row: [KeySpec]) {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(stack)

        let total = row.reduce(CGFloat(0)) { $0 + width($1) }

        for spec in row {
            let button = makeButton(for: spec)
            stack.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            button.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: width(spec) / total).isActive = true
        }
    }

    private func makeButton(for spec: KeySpec) -> KeyButton {
        let button = KeyButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.spec = spec
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 7
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.setTitleColor(.label, for: .normal)
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)

        switch spec {
        case .char(let model):
            button.model = model
            charButtons.append(button)
        case .tab:
            button.setTitle("⇥", for: .normal)
        case .delete:
            button.setTitle("⌫", for: .normal)
        case .shift:
            button.setTitle("⇧", for: .normal)
            shiftButton = button
        case .symbols:
            symbolsButton = button
        case .space:
            button.setTitle("espace", for: .normal)
        case .enter:
            button.setTitle("retour", for: .normal)
        case .globe:
            button.setTitle("🌐", for: .normal)
        case .cmd:
            button.setTitle("⌘", for: .normal)
            cmdButton = button
        case .opt:
            button.setTitle("⌥", for: .normal)
            optButton = button
        case .ctrl:
            button.setTitle("⌃", for: .normal)
            ctrlButton = button
        case .arrow(let key):
            switch key {
            case .left:  button.setTitle("◀", for: .normal)
            case .right: button.setTitle("▶", for: .normal)
            case .up:    button.setTitle("▲", for: .normal)
            default:     button.setTitle("▼", for: .normal)
            }
        }
        return button
    }

    private func rebuildTitles() {
        for button in charButtons {
            guard let model = button.model else { continue }
            let title: String
            if isSymbols {
                title = isShifted ? model.symbolsShifted : model.symbols
            } else {
                title = isShifted ? model.lettersShifted : model.letters
            }
            button.setTitle(title, for: .normal)
        }
        shiftButton?.setTitle(isSymbols ? (isShifted ? "abc" : "ABC") : "⇧", for: .normal)
        symbolsButton?.setTitle(isSymbols ? "ABC" : "123", for: .normal)
        setActive(shiftButton, isShifted)
        setActive(cmdButton, cmd)
        setActive(optButton, opt)
        setActive(ctrlButton, ctrl)
    }

    private func setActive(_ button: KeyButton?, _ active: Bool) {
        guard let button else { return }
        UIView.animate(withDuration: 0.12) {
            button.backgroundColor = active ? .systemBlue : .secondarySystemBackground
            button.setTitleColor(active ? .white : .label, for: .normal)
        }
    }

    private func refreshStatus() {
        guard hasFullAccess else {
            statusLabel.text = "Activez « Autoriser l'accès complet » dans Réglages > Claviers"
            statusLabel.textColor = .systemOrange
            return
        }

        switch connection?.pairingState ?? .idle {
        case .paired:
            statusLabel.text = "● Connecté au Mac"
            statusLabel.textColor = .systemGreen

        case .awaitingPin, .refused:
            // L'extension ne peut pas afficher de champ de saisie utilisable :
            // l'appairage se fait dans l'app.
            statusLabel.text = "Ouvrez l'app TrackPad Hub pour autoriser cet iPhone"
            statusLabel.textColor = .systemOrange

        case .verifying:
            statusLabel.text = "○ Vérification…"
            statusLabel.textColor = .secondaryLabel

        case .idle:
            statusLabel.text = (connection?.isConnected ?? false)
                ? "○ Vérification…"
                : "○ Recherche du Mac…"
            statusLabel.textColor = .secondaryLabel
        }
    }

    // MARK: - Actions

    @objc private func keyTapped(_ button: KeyButton) {
        guard let spec = button.spec else { return }
        switch spec {
        case .char(let model):
            let char: Character
            if isSymbols {
                char = Character(isShifted ? model.symbolsShifted : model.symbols)
            } else {
                char = Character(isShifted ? model.lettersShifted : model.letters)
            }
            sendChar(char)
            if isShifted && !isSymbols {
                isShifted = false
                rebuildTitles()
            }

        case .tab:
            sendKey(.tab)
        case .delete:
            sendKey(.delete)
        case .space:
            sendKey(.space)
        case .enter:
            sendKey(.return)
        case .globe:
            advanceToNextInputMode()
        case .arrow(let key):
            sendKey(key)

        case .shift:
            isShifted.toggle()
            rebuildTitles()
        case .symbols:
            isSymbols.toggle()
            isShifted = false
            rebuildTitles()
        case .cmd:
            cmd.toggle()
            rebuildTitles()
        case .opt:
            opt.toggle()
            rebuildTitles()
        case .ctrl:
            ctrl.toggle()
            rebuildTitles()
        }
    }
}

/// Bouton d'une touche du clavier.
final class KeyButton: UIButton {
    var spec: KeyboardViewController.KeySpec?
    var model: KeyboardViewController.KeyModel?
}
