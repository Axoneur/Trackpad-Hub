import WidgetKit
import SwiftUI
import AppIntents

/// Widgets d'écran d'accueil et d'écran verrouillé.
///
/// Un widget n'a pas accès au réseau local : il affiche le dernier état
/// transmis par l'app, avec sa date, et propose des actions qui passent par
/// des intentions.

// MARK: - Données

struct MacEntry: TimelineEntry {
    let date: Date
    let vitals: MacVitals?
    let lastSeen: Date?
    let hostName: String

    /// Au-delà de dix minutes sans nouvelle, on ne prétend plus que
    /// l'information est à jour.
    var isStale: Bool {
        guard let lastSeen else { return true }
        return Date().timeIntervalSince(lastSeen) > 600
    }

    static let placeholder = MacEntry(
        date: Date(),
        vitals: MacVitals(batteryPercent: 72, isCharging: false,
                          diskFreeGB: 134, diskTotalGB: 245,
                          memoryUsedGB: 11.7, memoryTotalGB: 16,
                          cpuPercent: 24, uptime: "19 h", hostName: "MacBook Air"),
        lastSeen: Date(),
        hostName: "MacBook Air")
}

struct MacProvider: TimelineProvider {
    func placeholder(in context: Context) -> MacEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (MacEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MacEntry>) -> Void) {
        let entry = currentEntry()
        // L'app rafraîchit le widget quand elle reçoit de nouvelles données ;
        // cette échéance n'est qu'un filet de sécurité.
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> MacEntry {
        let stored = SharedStore.loadVitals()
        return MacEntry(date: Date(),
                        vitals: stored?.vitals,
                        lastSeen: stored?.date,
                        hostName: SharedStore.hostName)
    }
}

// MARK: - Widget « État du Mac »

struct MacStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MacStatusWidget", provider: MacProvider()) { entry in
            MacStatusView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("État du Mac")
        .description("Batterie, processeur et mémoire de votre Mac.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct MacStatusView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MacEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessory
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            if let vitals = entry.vitals {
                if let battery = vitals.batteryPercent {
                    metric("Batterie", "\(battery) %",
                           value: Double(battery) / 100,
                           tint: battery <= 20 ? .red : .green)
                }
                metric("Processeur", "\(Int(vitals.cpuPercent)) %",
                       value: vitals.cpuPercent / 100, tint: .orange)
                metric("Mémoire",
                       "\(Int(vitals.memoryUsedGB)) / \(Int(vitals.memoryTotalGB)) Go",
                       value: vitals.memoryUsedGB / max(vitals.memoryTotalGB, 1), tint: .purple)
            } else {
                Text("Ouvrez l'app pour relever l'état")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            small
            if let vitals = entry.vitals {
                VStack(alignment: .leading, spacing: 6) {
                    Spacer(minLength: 18)
                    metric("Disque", "\(Int(vitals.diskFreeGB)) Go libres",
                           value: 1 - vitals.diskFreeGB / max(vitals.diskTotalGB, 1), tint: .blue)
                    Label(vitals.uptime, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.hostName).font(.headline)
            if let vitals = entry.vitals {
                Text("\(vitals.batteryPercent.map { "\($0) % · " } ?? "")CPU \(Int(vitals.cpuPercent)) %")
                    .font(.caption)
            } else {
                Text("Aucune donnée").font(.caption)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "desktopcomputer")
                .font(.caption)
                .foregroundStyle(.tint)
            Text(entry.hostName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            if entry.isStale {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metric(_ title: String, _ detail: String,
                        value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.caption2)
                Spacer()
                Text(detail).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(value, 0), 1))
                .tint(tint)
                .scaleEffect(x: 1, y: 0.7, anchor: .center)
        }
        .opacity(entry.isStale ? 0.55 : 1)
    }
}

// MARK: - Widget « Commandes »

struct MacControlsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MacControlsWidget", provider: MacProvider()) { entry in
            MacControlsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Commandes du Mac")
        .description("Réveiller, verrouiller ou endormir votre Mac.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MacControlsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MacEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "desktopcomputer")
                    .font(.caption)
                    .foregroundStyle(.tint)
                Text(entry.hostName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
            }

            // Seul le réveil agit directement : le paquet magique part du
            // widget lui-même, sans rien ouvrir. Les autres actions doivent
            // passer par l'app, qui seule tient la connexion au Mac — d'où
            // la flèche qui prévient que l'app va s'ouvrir.
            //
            // Lecture, pause et piste suivante ont été retirés : ouvrir une
            // app entière pour appuyer sur pause est plus lent que de prendre
            // le Mac. Ils restent dans l'onglet Média, où ils sont immédiats.
            button(WakeMacIntent(), icon: "bolt.horizontal",
                   label: "Réveiller", tint: .orange, opensApp: false)

            HStack(spacing: 8) {
                button(LockMacIntent(), icon: "lock.fill",
                       label: "Verrouiller", tint: .blue, opensApp: true)
                button(SleepMacIntent(), icon: "moon.fill",
                       label: "Veille", tint: .indigo, opensApp: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func button<I: AppIntent>(_ intent: I, icon: String, label: String,
                                      tint: Color, opensApp: Bool) -> some View {
        Button(intent: intent) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                if family != .systemSmall {
                    Text(label).font(.caption2.weight(.medium))
                }
                if opensApp {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 9))
                        .opacity(0.6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .background(tint.opacity(0.16), in: .rect(cornerRadius: 10))
    }
}

// MARK: - Déclaration

@main
struct TrackPadWidgets: WidgetBundle {
    var body: some Widget {
        MacStatusWidget()
        MacControlsWidget()
    }
}
