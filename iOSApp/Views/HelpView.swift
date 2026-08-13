import SwiftUI

/// Un tutoriel : à quoi sert la fonctionnalité, comment s'en servir, et ce
/// qu'il faut vérifier quand ça ne marche pas.
struct HelpTopic: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    /// Une phrase : à quoi ça sert.
    let purpose: String
    /// Étapes numérotées.
    let steps: [String]
    /// Points de dépannage : (symptôme, solution).
    var troubleshooting: [(String, String)] = []
    /// Astuces facultatives.
    var tips: [String] = []
}

enum HelpLibrary {

    static let topics: [HelpTopic] = [
        HelpTopic(
            title: "Premiers pas",
            icon: "sparkles",
            tint: .yellow,
            purpose: "Relier l'iPhone au Mac pour la première fois.",
            steps: [
                "Sur le Mac, ouvrez l'app TrackPad Hub et laissez-la ouverte.",
                "Cliquez sur « Accorder l'accès » et cochez TrackPad Hub dans Réglages Système > Confidentialité et sécurité > Accessibilité.",
                "Sur l'iPhone, ouvrez l'app et acceptez l'accès au réseau local.",
                "Un QR code et un code à 6 chiffres apparaissent sur le Mac : scannez le QR, ou tapez le code.",
                "La pastille en haut de l'écran passe au vert : vous êtes connecté."
            ],
            troubleshooting: [
                ("« Recherche du Mac… » ne s'arrête pas",
                 "Les deux appareils doivent être sur le même réseau Wi-Fi, et l'app macOS ouverte."),
                ("Le curseur ne bouge pas",
                 "L'autorisation Accessibilité n'est pas accordée sur le Mac."),
                ("Aucun code ne s'affiche sur le Mac",
                 "Le Mac ne demande un code que pour un appareil inconnu. Utilisez « Oublier » sur le Mac pour recommencer.")
            ],
            tips: [
                "L'appairage n'est demandé qu'une fois : ensuite la connexion est automatique."
            ]
        ),

        HelpTopic(
            title: "Trackpad",
            icon: "rectangle.and.hand.point.up.left",
            tint: .blue,
            purpose: "Piloter le curseur du Mac comme sur un vrai trackpad.",
            steps: [
                "1 doigt qui glisse : déplace le curseur.",
                "1 doigt, appui bref : clic gauche.",
                "2 doigts qui glissent : défilement, avec inertie.",
                "2 doigts qu'on écarte ou rapproche : zoom.",
                "2 doigts, appui bref : clic droit.",
                "3 doigts, appui bref : clic milieu.",
                "3 doigts vers le haut : Mission Control. Vers le bas : App Exposé.",
                "3 doigts sur les côtés : bureau précédent ou suivant.",
                "4 doigts qu'on écarte : afficher le bureau. Qu'on rapproche : recherche.",
                "Appui bref puis glisser : glisser-déposer."
            ],
            troubleshooting: [
                ("Le défilement part à l'envers",
                 "Réglages > Trackpad > Défilement naturel."),
                ("Le curseur est trop lent ou trop nerveux",
                 "Touchez l'icône compteur sous la surface pour régler les vitesses."),
                ("Le clic droit envoie deux clics gauches",
                 "Posez bien les deux doigts en même temps, sans les faire glisser.")
            ],
            tips: [
                "L'accélération rend les petits gestes précis et les grands gestes rapides. Désactivable dans Réglages.",
                "Les boutons sous la surface servent quand il faut cliquer sans bouger le curseur."
            ]
        ),

        HelpTopic(
            title: "Défilement par inclinaison",
            icon: "arrow.up.and.down.circle",
            tint: .teal,
            purpose: "Faire défiler en inclinant l'iPhone, le doigt libre.",
            steps: [
                "Sous le trackpad, touchez l'icône flèches haut-bas.",
                "La position du téléphone à cet instant devient le repos.",
                "Inclinez vers l'avant ou vers vous pour défiler ; plus vous inclinez, plus ça va vite.",
                "Retouchez l'icône pour arrêter."
            ],
            troubleshooting: [
                ("Ça défile tout seul",
                 "Le repos a été pris dans une position inhabituelle. Arrêtez et relancez en tenant le téléphone comme vous allez le tenir."),
                ("Il ne se passe rien",
                 "Une zone morte d'environ 7° empêche le tremblement de la main de faire défiler. Inclinez davantage."),
                ("C'est trop rapide ou trop lent",
                 "Réglages > Capteurs > Vitesse d'inclinaison.")
            ],
            tips: [
                "Utile pour lire un article d'une main pendant que l'autre est prise."
            ]
        ),

        HelpTopic(
            title: "Mode poche",
            icon: "hand.raised.slash.fill",
            tint: .gray,
            purpose: "Empêcher les gestes accidentels quand l'iPhone est rangé.",
            steps: [
                "Réglages > Capteurs > activez « Mode poche ».",
                "Dès que le capteur de proximité est couvert — poche, table retournée — l'écran se voile et plus rien ne part vers le Mac.",
                "Découvrez l'écran : tout reprend."
            ],
            troubleshooting: [
                ("Le voile ne disparaît pas",
                 "Quelque chose couvre encore le haut de l'écran, près de l'écouteur."),
                ("Rien ne se passe quand je couvre l'écran",
                 "Le capteur ne répond pas sur cet appareil. Le réglage reste sans effet.")
            ],
            tips: [
                "Un clic maintenu est relâché automatiquement quand le mode poche s'active : le Mac ne reste jamais bloqué en glissement."
            ]
        ),

        HelpTopic(
            title: "Accessibilité",
            icon: "figure.wave",
            tint: .green,
            purpose: "Adapter l'interface à la vue et à la prise en main.",
            steps: [
                "Réglages > Accessibilité.",
                "« Fort contraste » renforce la graisse des textes et les contours.",
                "« Mode une main » agrandit les boutons sous le trackpad et les remonte du bas de l'écran, à portée du pouce."
            ],
            tips: [
                "Les deux réglages se combinent, et n'affectent pas ce qui est envoyé au Mac."
            ]
        ),

        HelpTopic(
            title: "Mode jeu",
            icon: "gamecontroller.fill",
            tint: .red,
            purpose: "Une manette plein écran, traduite en touches maintenues.",
            steps: [
                "Onglet Mac > Mode jeu. L'écran passe en manette : plus de barre, plus de défilement.",
                "Manche à gauche : quatre directions, maintenues tant que le pouce reste écarté du centre.",
                "Losange à droite : quatre boutons d'action.",
                "En haut : L1, L2 à gauche, R1, R2 à droite.",
                "L'engrenage en haut au centre règle les touches de votre jeu."
            ],
            troubleshooting: [
                ("Le personnage continue d'avancer",
                 "Toutes les touches sont relâchées en quittant l'écran. Revenez-y et ressortez."),
                ("Le jeu ne réagit pas",
                 "Il doit avoir le focus sur le Mac. Certains jeux en plein écran ignorent les touches synthétiques."),
                ("Les directions sont inversées ou décalées",
                 "Les touches par défaut sont ZQSD, pour clavier AZERTY. Touchez l'engrenage pour les changer.")
            ],
            tips: [
                "Le Mac résout la touche physique contre sa disposition active : « Z » vise bien la touche que vous avez sous le doigt.",
                "Une zone morte d'un tiers empêche le pouce posé au repos d'envoyer une direction."
            ]
        ),

        HelpTopic(
            title: "Statistiques",
            icon: "chart.bar.fill",
            tint: .mint,
            purpose: "Voir le temps passé connecté et les gestes les plus utilisés.",
            steps: [
                "Onglet Mac > Statistiques.",
                "Les actions sont classées par fréquence, la plus utilisée en tête.",
                "L'icône en haut à droite remet tout à zéro."
            ],
            tips: [
                "Ces chiffres restent sur l'iPhone : ils ne sont ni envoyés au Mac, ni transmis ailleurs."
            ]
        ),

        HelpTopic(
            title: "Macros",
            icon: "wand.and.rays",
            tint: .purple,
            purpose: "Enregistrer une séquence d'actions et la rejouer d'un appui.",
            steps: [
                "Onglet Mac > Macros > « Enregistrer une macro ».",
                "Faites ce que vous voulez automatiser : touches, clics, raccourcis, fenêtres, onglets.",
                "Touchez « Terminer », donnez un nom.",
                "Le bouton lecture rejoue la séquence, avec les mêmes pauses que vous avez faites."
            ],
            troubleshooting: [
                ("Ma macro ne rejoue pas les mouvements du curseur",
                 "C'est voulu. Un déplacement dépend de l'endroit exact où était le curseur : le rejouer ailleurs produirait un gribouillage. Utilisez plutôt les fenêtres et les raccourcis, qui visent une cible et non une position."),
                ("La macro va trop vite pour l'app visée",
                 "Marquez une pause plus longue pendant l'enregistrement : les délais sont conservés tels quels."),
                ("Le bouton d'enregistrement est grisé",
                 "L'iPhone n'est pas encore appairé au Mac.")
            ],
            tips: [
                "Les pauses sont plafonnées à cinq secondes : une interruption pendant l'enregistrement ne fige pas la macro.",
                "Lancer une macro pendant un enregistrement ne la recopie pas dedans."
            ]
        ),

        HelpTopic(
            title: "Reprise de lecture",
            icon: "iphone.and.arrow.right.outward",
            tint: .pink,
            purpose: "Continuer sur l'iPhone ce qui joue sur le Mac.",
            steps: [
                "Lancez une vidéo ou un morceau sur le Mac.",
                "Onglet Média : une carte « En cours sur le Mac » apparaît.",
                "Touchez « Continuer sur l'iPhone » : le lien s'ouvre ici et le Mac se met en pause."
            ],
            troubleshooting: [
                ("Rien n'apparaît",
                 "La détection interroge Spotify, Musique, puis le navigateur. Une app qui n'expose rien à AppleScript ne peut pas être détectée."),
                ("Ça reprend au début",
                 "Seuls Spotify et YouTube savent reprendre à la seconde. Ailleurs, le lien rouvre la page.")
            ],
            tips: [
                "La pause du Mac se désactive dans la carte, si vous voulez garder le son sur les deux."
            ]
        ),

        HelpTopic(
            title: "Les boutons du trackpad",
            icon: "hand.point.up.left.fill",
            tint: .indigo,
            purpose: "Ce que fait chaque bouton, de gauche à droite.",
            steps: [
                "Curseur avec index — Clic gauche. Le même qu'un appui bref à un doigt, mais sans bouger le curseur.",
                "Curseur avec deux traits — Clic droit. Ouvre le menu contextuel, comme un appui à deux doigts.",
                "Main levée — Maintenir le clic. Le bouton gauche reste enfoncé jusqu'au prochain appui : c'est ce qui permet de déplacer une fenêtre ou de la redimensionner en faisant glisser un doigt. Le bouton s'entoure de couleur tant que le clic est maintenu.",
                "Main avec point — Souris en l'air. Le curseur suit l'inclinaison de l'iPhone. Grisé si les capteurs sont indisponibles.",
                "Viseur — Recentrer la souris en l'air, quand le curseur a dérivé. Actif seulement quand elle tourne.",
                "Compteur — Réglages de vitesse : sensibilité du curseur et du défilement.",
                "Clavier — Ouvre le clavier par-dessus le trackpad, sans quitter l'écran."
            ],
            troubleshooting: [
                ("Tout ce que je touche se met à glisser",
                 "Le clic est resté maintenu : touchez à nouveau le bouton « main levée ». Il est entouré de couleur quand il est actif."),
                ("Je n'arrive pas à déplacer une fenêtre",
                 "Placez d'abord le curseur sur sa barre de titre, touchez « Maintenir le clic », faites glisser un doigt, puis touchez à nouveau pour relâcher."),
                ("Le bouton « souris en l'air » est grisé",
                 "Les capteurs de mouvement ne répondent pas. Fermez et rouvrez l'app.")
            ],
            tips: [
                "Le clic maintenu se relâche tout seul si vous quittez l'écran du trackpad ou si la liaison tombe : le Mac ne reste jamais bloqué en glissement.",
                "Pour un glisser-déposer court, l'appui bref puis glisser reste plus rapide que le clic maintenu."
            ]
        ),

        HelpTopic(
            title: "Souris en l'air",
            icon: "dot.circle.and.hand.point.up.left.fill",
            tint: .teal,
            purpose: "Déplacer le curseur en inclinant l'iPhone, sans toucher l'écran — utile à distance, pendant une présentation.",
            steps: [
                "Dans l'onglet Trackpad, touchez l'icône de main pour activer le mode.",
                "Tenez l'iPhone devant vous et inclinez-le : le curseur suit.",
                "Touchez l'icône de cible pour recentrer, comme quand on soulève une souris pour la reposer au milieu du tapis.",
                "Retouchez l'icône de main pour revenir au trackpad."
            ],
            tips: [
                "La sensibilité se règle avec l'icône compteur, une fois le mode activé.",
                "Un léger tremblement est ignoré : le curseur ne bouge qu'à partir d'un vrai mouvement."
            ]
        ),

        HelpTopic(
            title: "Clavier",
            icon: "keyboard",
            tint: .indigo,
            purpose: "Taper sur le Mac depuis l'iPhone, y compris les raccourcis.",
            steps: [
                "Écrivez dans le champ du haut et touchez l'avion en papier pour tout envoyer d'un coup.",
                "Ou touchez les lettres une à une sur le clavier du bas.",
                "Pour un raccourci : touchez le ou les modificateurs (⌘ ⌥ ⌃ ⇧), puis la lettre.",
                "Les modificateurs se relâchent seuls après la frappe, comme sur un vrai clavier."
            ],
            troubleshooting: [
                ("Les mauvaises lettres arrivent sur le Mac",
                 "Dans l'app macOS, choisissez la bonne disposition au lieu de « Suivre le clavier actif »."),
                ("Le clavier affiché n'est pas dans le bon ordre",
                 "Réglages > Clavier > Disposition affichée : AZERTY, QWERTY ou QWERTZ.")
            ],
            tips: [
                "L'iPhone envoie des caractères, pas des positions de touches : ⌘A reste « tout sélectionner » même sur un Mac en AZERTY.",
                "Les accents partent comme de vraies frappes, sans toucher à votre presse-papiers."
            ]
        ),

        HelpTopic(
            title: "Dictée vocale",
            icon: "mic.fill",
            tint: .red,
            purpose: "Parler au lieu de taper : le texte est transcrit puis écrit sur le Mac.",
            steps: [
                "Onglet Clavier, touchez « Dictée vocale ».",
                "Autorisez le micro et la reconnaissance vocale à la première utilisation.",
                "Parlez : la transcription s'affiche au fur et à mesure.",
                "Touchez « Arrêter la dictée » : le texte part sur le Mac."
            ],
            tips: [
                "La reconnaissance se fait sur l'iPhone quand le modèle français est installé : l'audio ne part pas chez Apple.",
                "Placez le curseur dans le bon champ sur le Mac avant de commencer."
            ]
        ),

        HelpTopic(
            title: "Presse-papiers partagé",
            icon: "doc.on.clipboard",
            tint: .green,
            purpose: "Faire passer du texte d'un appareil à l'autre sans câble ni e-mail à soi-même.",
            steps: [
                "Copiez quelque chose sur le Mac : le texte remonte tout seul sur l'iPhone.",
                "« Copier ici » place ce texte dans le presse-papiers de l'iPhone.",
                "« Envoyer » pousse le presse-papiers de l'iPhone vers le Mac.",
                "« Récupérer » redemande au Mac son contenu actuel."
            ],
            tips: [
                "Seul le texte est pris en charge, pas les images ni les fichiers."
            ]
        ),

        HelpTopic(
            title: "Applications du Mac",
            icon: "square.stack",
            tint: .orange,
            purpose: "Voir, lancer, masquer, suspendre ou fermer les apps du Mac à distance.",
            steps: [
                "Onglet Mac : les apps ouvertes défilent en haut, l'app active en premier.",
                "« Tout voir » ouvre la liste complète, avec recherche.",
                "Onglet « Ouvertes » : touchez une app pour ses actions.",
                "Onglet « Installées » : touchez une app pour la lancer.",
                "Afficher, Masquer, Suspendre, Reprendre, Quitter, Forcer à quitter."
            ],
            tips: [
                "« Suspendre » gèle l'app : elle ne consomme plus de processeur mais garde tout son état. Pratique pour une app qui fait tourner le ventilateur.",
                "« Forcer à quitter » est à réserver aux apps qui ne répondent plus : le travail non enregistré est perdu."
            ]
        ),

        HelpTopic(
            title: "Média et présentation",
            icon: "playpause.fill",
            tint: .pink,
            purpose: "Piloter la musique, le volume, et faire défiler une présentation.",
            steps: [
                "Les boutons de lecture agissent sur l'app qui joue, quelle qu'elle soit.",
                "Le volume passe par le réglage système du Mac.",
                "Pour une présentation : lancez le diaporama sur le Mac, puis touchez « Démarrer ».",
                "Les flèches changent de diapositive ; « Écran noir » masque temporairement."
            ],
            troubleshooting: [
                ("Lecture/pause sans effet",
                 "Certaines versions de macOS bloquent le contrôle média des apps tierces. Le repli par touches clavier prend alors le relais, ce qui exige l'autorisation Accessibilité.")
            ],
            tips: [
                "Le minuteur vibre à chaque minute écoulée : vous suivez votre temps sans regarder l'écran."
            ]
        ),

        HelpTopic(
            title: "Contrôles système",
            icon: "power",
            tint: .purple,
            purpose: "Mettre en veille, verrouiller, redémarrer ou éteindre le Mac de loin.",
            steps: [
                "Onglet Mac, section Alimentation.",
                "Redémarrer, Éteindre et Déconnexion demandent confirmation.",
                "À la première utilisation, macOS demande l'autorisation « Automatisation » : acceptez-la."
            ],
            troubleshooting: [
                ("Rien ne se passe sur Veille ou Éteindre",
                 "L'autorisation Automatisation a été refusée. Réglages Système > Confidentialité et sécurité > Automatisation.")
            ]
        ),

        HelpTopic(
            title: "Raccourcis",
            icon: "bolt.fill",
            tint: .cyan,
            purpose: "Lancer une app, ouvrir un lien ou exécuter un raccourci du Mac d'un seul toucher.",
            steps: [
                "Onglet Mac > Raccourcis, puis « + ».",
                "Application : choisissez-la dans la liste.",
                "Lien : l'URL s'ouvrira dans le navigateur du Mac.",
                "Raccourci : tapez le nom exact d'un raccourci de l'app Raccourcis du Mac.",
                "Appui long sur une vignette pour la supprimer."
            ]
        ),

        HelpTopic(
            title: "Clavier système (extension)",
            icon: "globe",
            tint: .brown,
            purpose: "Taper vers le Mac depuis n'importe quelle app de l'iPhone, sans revenir dans TrackPad Hub.",
            steps: [
                "Réglages iOS > Général > Clavier > Claviers > Ajouter un clavier.",
                "Choisissez « Clavier TrackPad Hub ».",
                "Touchez son nom, puis activez « Autoriser l'accès complet » — nécessaire pour accéder au réseau.",
                "Dans n'importe quel champ de saisie, basculez avec l'icône 🌐."
            ],
            troubleshooting: [
                ("Le clavier n'envoie rien",
                 "Vérifiez « Autoriser l'accès complet », et appairez d'abord dans l'app principale."),
                ("Il redemande un code",
                 "Les deux cibles doivent être signées avec la même équipe Apple dans Xcode.")
            ],
            tips: [
                "L'extension réutilise l'appairage de l'app : aucun code à ressaisir."
            ]
        ),

        HelpTopic(
            title: "Mises à jour et signature",
            icon: "arrow.down.circle.fill",
            tint: .blue,
            purpose: "Rester à jour, et comprendre pourquoi l'app expire.",
            steps: [
                "À l'ouverture, l'app interroge une fois par jour les versions publiées sur GitHub.",
                "Quand une version plus récente existe, un bandeau apparaît en haut des Réglages.",
                "Sur le Mac : « git pull » puis « ./reinstall.sh --all ».",
                "Un compte Apple gratuit signe pour 7 jours : passé ce délai, l'app iPhone cesse de s'ouvrir.",
                "Vous êtes prévenu par notification à trois moments : trois jours avant, la veille, et le jour même.",
                "L'iPhone dépose ces avertissements à l'avance, dès l'ouverture : une fois expirée l'app ne s'ouvre plus, elle ne pourrait donc plus prévenir.",
                "L'app macOS prévient elle aussi, et propose de renouveler en un clic.",
                "Délai et heure des rappels se règlent dans Réglages > Rappels d'expiration."
            ],
            troubleshooting: [
                ("L'app iPhone ne s'ouvre plus du tout",
                 "La signature a expiré. Ce n'est pas une panne. Sur le Mac : ./reinstall.sh --all"),
                ("Je ne veux plus y penser",
                 "Sur le Mac, bouton « Automatiser tous les 6 jours ». Un agent système s'en charge, l'iPhone devant être branché à ce moment-là."),
                ("Aucun bandeau de mise à jour n'apparaît",
                 "C'est qu'il n'y en a pas. La vérification a lieu une fois par jour au maximum."),
                ("Je ne reçois aucune notification d'expiration",
                 "Réglages > Notifications > TrackPad Hub. Après un refus, iOS ne redemande jamais : seuls les Réglages débloquent.")
            ],
            tips: [
                "Le compte payant supprime la limite des 7 jours, mais n'est utile que pour distribuer l'app.",
                "La vérification n'envoie rien : elle lit une page publique de GitHub.",
                "Trois avertissements seulement, jamais un par jour : un rappel quotidien finit coupé, et celui qui compte vraiment n'est plus lu."
            ]
        ),

        HelpTopic(
            title: "Sécurité",
            icon: "lock.shield",
            tint: .mint,
            purpose: "Comprendre ce qui protège votre Mac.",
            steps: [
                "Se connecter au réseau ne donne aucun droit : sans appairage, toutes les commandes sont rejetées.",
                "Le Mac envoie un défi aléatoire ; l'iPhone répond par une signature du code. Le code lui-même ne circule jamais.",
                "Après réussite, un jeton permanent est stocké dans le trousseau des deux côtés.",
                "5 codes erronés bloquent l'appareil.",
                "Sur le Mac, « Oublier » retire un appareil : il devra refaire un appairage."
            ]
        )
    ]
}

// MARK: - Écrans

struct HelpView: View {
    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                LazyVStack(spacing: 10) {
                    Text("Chaque fonctionnalité expliquée pas à pas.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    ForEach(HelpLibrary.topics) { topic in
                        NavigationLink {
                            HelpDetailView(topic: topic)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: topic.icon)
                                    .font(.system(size: 17))
                                    .foregroundStyle(topic.tint)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(topic.title)
                                        .font(.subheadline.weight(.medium))
                                    Text(topic.purpose)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .foregroundStyle(.primary)
                            .padding(14)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .glassSurface(cornerRadius: Design.Radius.tile, interactive: true)
                    }
                }
                .padding(.horizontal, Design.Space.wide)
                .padding(.bottom, Design.Space.wide)
            }
        }
        .navigationTitle("Aide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpDetailView: View {
    let topic: HelpTopic

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: Design.Space.normal) {
                    GlassTile(tint: topic.tint) {
                        HStack(spacing: 12) {
                            Image(systemName: topic.icon)
                                .font(.title2)
                                .foregroundStyle(topic.tint)
                            Text(topic.purpose)
                                .font(.subheadline)
                        }
                    }

                    section("Comment faire", icon: "list.number") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(topic.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Circle().fill(topic.tint))
                                    Text(step)
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    if !topic.tips.isEmpty {
                        section("Bon à savoir", icon: "lightbulb") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(topic.tips.enumerated()), id: \.offset) { _, tip in
                                    Label(tip, systemImage: "sparkle")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !topic.troubleshooting.isEmpty {
                        section("Si ça ne marche pas", icon: "wrench.and.screwdriver") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(topic.troubleshooting.enumerated()), id: \.offset) { _, entry in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.0)
                                            .font(.footnote.weight(.semibold))
                                        Text(entry.1)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Design.Space.wide)
                .padding(.bottom, Design.Space.wide)
            }
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section<Content: View>(_ title: String, icon: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: Design.Space.tight) {
            SectionHeader(title: title, systemImage: icon)
            GlassTile { content() }
        }
    }
}
