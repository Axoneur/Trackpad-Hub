import Foundation
import CoreBluetooth

/// Liaison de secours en Bluetooth LE.
///
/// ## À quoi elle sert
///
/// Elle ne remplace pas le Wi-Fi, elle prend le relais quand il n'y en a pas :
/// hôtel, avion, réseau invité qui isole les appareils. Aujourd'hui, sans
/// réseau commun, l'app ne fonctionne pas du tout.
///
/// Le débit suffit largement pour le chemin chaud — un déplacement pèse
/// 11 octets, à 120 par seconde cela fait 1,3 ko/s, très en deçà de ce que
/// porte le BLE. La latence, elle, est moins bonne : l'intervalle de connexion
/// BLE va de 15 à 30 ms, contre 2 à 5 ms en Wi-Fi. D'où le rôle de secours et
/// non de remplacement.
///
/// Le transfert de fichiers reste possible mais lent : à prévoir en Wi-Fi.
///
/// ## État : écrit et compilé, **pas encore branché**
///
/// Le chiffrement vit aujourd'hui dans `DirectLink` (clé dérivée du jeton,
/// AES-GCM, compteur anti-rejeu par canal). Brancher le Bluetooth tel quel
/// ferait circuler les frappes clavier **en clair** sur les ondes — exactement
/// ce qu'on a refusé en retirant MultipeerConnectivity.
///
/// Le branchement suppose donc d'abord de sortir le chiffrement de
/// `DirectLink` vers un type partagé, que les deux transports utiliseraient.
/// C'est un remaniement du seul composant qui vient d'être validé de bout en
/// bout : à faire posément, pas en fin de course.
///
/// ## Rôles
///
/// L'iPhone **annonce** (périphérique), le Mac **cherche** (central). C'est
/// l'inverse du Wi-Fi, où le Mac annonce — mais c'est l'usage naturel du BLE :
/// l'appareil mobile annonce, la machine fixe scanne, et un périphérique BLE
/// consomme moins d'énergie qu'un central.
///
/// ## Découpage
///
/// Le BLE transporte des paquets courts — l'unité de transmission dépasse
/// rarement 180 octets utiles. Les charges plus longues (JSON, listes d'apps)
/// sont donc découpées, avec un octet d'en-tête : bit 7 à 1 signifie « ce
/// morceau n'est pas le dernier ». Sans ce marqueur, impossible de savoir où
/// s'arrête un message quand deux se suivent.
final class BluetoothLink: NSObject {

    /// Identifiants propres à l'app. Ils ne changent jamais : les modifier
    /// rendrait les versions incompatibles entre elles.
    static let serviceUUID = CBUUID(string: "8F1D2A40-3C6E-4B2A-9D7F-1E5C0B3A7D21")
    /// L'iPhone écrit ici, le Mac lit.
    static let toHostUUID = CBUUID(string: "8F1D2A41-3C6E-4B2A-9D7F-1E5C0B3A7D21")
    /// Le Mac notifie ici, l'iPhone reçoit.
    static let toClientUUID = CBUUID(string: "8F1D2A42-3C6E-4B2A-9D7F-1E5C0B3A7D21")

    // MARK: - Rappels

    var onConnected: (() -> Void)?
    var onLost: (() -> Void)?
    var onData: ((Data) -> Void)?

    /// Vrai quand la liaison Bluetooth porte réellement des messages.
    private(set) var isConnected = false {
        didSet {
            guard isConnected != oldValue else { return }
            isConnected ? onConnected?() : onLost?()
        }
    }

    private let isHost: Bool
    private let queue = DispatchQueue(label: "com.trackpadhub.ble")

    // Côté Mac
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?

    // Côté iPhone
    private var peripheralManager: CBPeripheralManager?
    private var notifyCharacteristic: CBMutableCharacteristic?
    private var subscribers: [CBCentral] = []

    /// Réassemblage des morceaux reçus.
    private var inbox = Data()

    init(isHost: Bool) {
        self.isHost = isHost
        super.init()
    }

    // MARK: - Cycle de vie

    func start() {
        if isHost {
            central = CBCentralManager(delegate: self, queue: queue)
        } else {
            peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
        }
    }

    func stop() {
        if let peripheral, let central {
            central.cancelPeripheralConnection(peripheral)
        }
        central?.stopScan()
        peripheralManager?.stopAdvertising()
        central = nil
        peripheralManager = nil
        self.peripheral = nil
        writeCharacteristic = nil
        subscribers.removeAll()
        isConnected = false
    }

    // MARK: - Envoi

    /// Taille utile d'un morceau.
    ///
    /// 180 octets tient dans l'unité de transmission négociée par tous les
    /// appareils récents, en gardant la marge de l'en-tête. Viser plus haut
    /// ferait silencieusement tomber les écritures sur les appareils plus
    /// anciens.
    private static let chunkSize = 180

    func send(_ payload: Data) {
        queue.async { [weak self] in
            guard let self, self.isConnected else { return }

            var offset = 0
            while offset < payload.count {
                let end = min(offset + Self.chunkSize, payload.count)
                let isLast = end == payload.count
                var chunk = Data([isLast ? 0x00 : 0x80])
                chunk.append(payload.subdata(in: offset..<end))
                self.write(chunk)
                offset = end
            }
        }
    }

    private func write(_ chunk: Data) {
        if isHost {
            guard let peripheral, let characteristic = writeCharacteristic else { return }
            // Sans accusé de réception : sur le chemin du curseur, attendre la
            // confirmation de chaque paquet coûterait plus que la perte
            // occasionnelle qu'elle évite.
            peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
        } else {
            guard let characteristic = notifyCharacteristic, !subscribers.isEmpty else { return }
            peripheralManager?.updateValue(chunk, for: characteristic, onSubscribedCentrals: subscribers)
        }
    }

    /// Réassemble et livre une charge complète.
    private func receive(_ chunk: Data) {
        guard let header = chunk.first else { return }
        inbox.append(chunk.dropFirst())

        // Bit 7 à 0 = dernier morceau : la charge est complète.
        guard header & 0x80 == 0 else {
            // Garde-fou : une suite de morceaux « à suivre » qui n'aboutit
            // jamais ferait grossir le tampon sans fin.
            if inbox.count > 1 << 20 { inbox.removeAll() }
            return
        }
        let payload = inbox
        inbox.removeAll()
        onData?(payload)
    }
}

// MARK: - Mac : rôle central

extension BluetoothLink: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ manager: CBCentralManager) {
        guard manager.state == .poweredOn else {
            isConnected = false
            return
        }
        manager.scanForPeripherals(withServices: [Self.serviceUUID])
    }

    func centralManager(_ manager: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard self.peripheral == nil else { return }
        self.peripheral = peripheral
        peripheral.delegate = self
        manager.stopScan()
        manager.connect(peripheral)
    }

    func centralManager(_ manager: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ manager: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        self.peripheral = nil
        writeCharacteristic = nil
        isConnected = false
        // On se remet à chercher : l'iPhone peut revenir à portée.
        if manager.state == .poweredOn {
            manager.scanForPeripherals(withServices: [Self.serviceUUID])
        }
    }
}

extension BluetoothLink: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else { return }
        peripheral.discoverCharacteristics([Self.toHostUUID, Self.toClientUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case Self.toHostUUID:
                writeCharacteristic = characteristic
            case Self.toClientUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
        isConnected = writeCharacteristic != nil
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let value = characteristic.value else { return }
        receive(value)
    }
}

// MARK: - iPhone : rôle périphérique

extension BluetoothLink: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ manager: CBPeripheralManager) {
        guard manager.state == .poweredOn else {
            isConnected = false
            return
        }

        let toHost = CBMutableCharacteristic(type: Self.toHostUUID,
                                             properties: [.write, .writeWithoutResponse],
                                             value: nil,
                                             permissions: [.writeable])
        let toClient = CBMutableCharacteristic(type: Self.toClientUUID,
                                               properties: [.notify],
                                               value: nil,
                                               permissions: [.readable])
        notifyCharacteristic = toClient

        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [toHost, toClient]
        manager.add(service)

        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID]
        ])
    }

    func peripheralManager(_ manager: CBPeripheralManager, central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        subscribers.append(central)
        isConnected = true
    }

    func peripheralManager(_ manager: CBPeripheralManager, central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribers.removeAll { $0.identifier == central.identifier }
        isConnected = !subscribers.isEmpty
    }

    func peripheralManager(_ manager: CBPeripheralManager,
                           didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let value = request.value { receive(value) }
        }
        // Un seul accusé pour le lot, comme le veut CoreBluetooth : répondre
        // à chaque requête séparément lève une exception.
        if let first = requests.first {
            manager.respond(to: first, withResult: .success)
        }
    }
}
