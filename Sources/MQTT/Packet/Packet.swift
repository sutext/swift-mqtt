//
//  Packet.swift
//  swift-mqtt
//
//  Created by supertext on 2024/12/23.
//

import Foundation

/// MQTT Packet type enumeration
enum PacketType: UInt8, Sendable {
    case CONNECT = 0x10
    case CONNACK = 0x20
    case PUBLISH = 0x30
    case PUBACK = 0x40
    case PUBREC = 0x50
    case PUBREL = 0x62
    case PUBCOMP = 0x70
    case SUBSCRIBE = 0x82
    case SUBACK = 0x90
    case UNSUBSCRIBE = 0xA2
    case UNSUBACK = 0xB0
    case PINGREQ = 0xC0
    case PINGRESP = 0xD0
    case DISCONNECT = 0xE0
    case AUTH = 0xF0
}

/// Protocol for all MQTT packet types
protocol Packet: CustomStringConvertible, Sendable {
    /// packet id (default to zero if not used)
    var id: UInt16 { get }
    /// packet type
    var type: PacketType { get }
    /// write packet to bytebuffer
    func write(version: MQTT.Version, to: inout DataBuffer) throws
    /// read packet from incoming packet
    static func read(version: MQTT.Version, from: IncomingPacket) throws -> Self
}

extension Packet {
    /// default packet to zero
    var id: UInt16 { 0 }
}


extension Packet {
    /// write fixed header for packet
    func writeFixedHeader(packetType: PacketType, flags: UInt8 = 0, size: Int, to byteBuffer: inout DataBuffer) {
        byteBuffer.writeInteger(packetType.rawValue | flags)
        Serializer.writeVarint(size, to: &byteBuffer)
    }
}

struct ConnectPacket: Packet {
    enum Flags {
        static let reserved: UInt8 = 1
        static let cleanSession: UInt8 = 2
        static let willFlag: UInt8 = 4
        static let willQoSShift: UInt8 = 3
        static let willQoSMask: UInt8 = 24
        static let willRetain: UInt8 = 32
        static let password: UInt8 = 64
        static let username: UInt8 = 128
    }

    var type: PacketType { .CONNECT }
    
    var description: String { "CONNECT" }

    /// Whether to establish a new, clean session or resume a previous session.
    let cleanSession: Bool

    /// MQTT keep alive period.
    let keepAliveSeconds: UInt16

    /// MQTT client identifier. Must be unique per client.
    let clientId: String

    /// MQTT user name.
    let username: String?

    /// MQTT password.
    let password: String?

    /// MQTT v5 properties
    let properties: Properties

    /// will published when connected
    let will: MQTT.Message?

    func copyNotClean()->ConnectPacket{
        ConnectPacket(
            cleanSession: false,
            keepAliveSeconds: self.keepAliveSeconds,
            clientId: self.clientId,
            username: self.username,
            password: self.password,
            properties: self.properties,
            will: self.will
        )
    }
    /// write connect packet to bytebuffer
    func write(version: MQTT.Version, to byteBuffer: inout DataBuffer) throws {
        writeFixedHeader(packetType: .CONNECT, size: self.packetSize(version: version), to: &byteBuffer)
        // variable header
        try Serializer.writeString("MQTT", to: &byteBuffer)
        // protocol level
        byteBuffer.writeInteger(version.byte)
        // connect flags
        var flags = self.cleanSession ? Flags.cleanSession : 0
        if let will {
            flags |= Flags.willFlag
            flags |= will.retain ? Flags.willRetain : 0
            flags |= will.qos.rawValue << Flags.willQoSShift
        }
        flags |= self.password != nil ? Flags.password : 0
        flags |= self.username != nil ? Flags.username : 0
        byteBuffer.writeInteger(flags)
        // keep alive
        byteBuffer.writeInteger(self.keepAliveSeconds)
        // v5 properties
        if version == .v5_0 {
            try self.properties.write(to: &byteBuffer)
        }

        // payload
        try Serializer.writeString(self.clientId, to: &byteBuffer)
        if let will {
            if version == .v5_0 {
                try will.properties.write(to: &byteBuffer)
            }
            try Serializer.writeString(will.topic, to: &byteBuffer)
            try Serializer.writeData(will.payload, to: &byteBuffer)
        }
        if let username {
            try Serializer.writeString(username, to: &byteBuffer)
        }
        if let password {
            try Serializer.writeString(password, to: &byteBuffer)
        }
    }

    /// read connect packet from incoming packet (not implemented)
    static func read(version: MQTT.Version, from: IncomingPacket) throws -> Self {
        throw MQTTError.noNeedImplemention
    }

    /// calculate size of connect packet
    func packetSize(version: MQTT.Version) -> Int {
        // variable header
        var size = 10
        // properties
        if version == .v5_0 {
            let propertiesPacketSize = self.properties.packetSize
            size += Serializer.varintPacketSize(propertiesPacketSize) + propertiesPacketSize
        }
        // payload
        // client identifier
        size += self.clientId.utf8.count + 2
        // will publish
        if let will {
            // properties
            if version == .v5_0 {
                let propertiesPacketSize = will.properties.packetSize
                size += Serializer.varintPacketSize(propertiesPacketSize) + propertiesPacketSize
            }
            // will topic
            size += will.topic.utf8.count + 2
            // will message
            size += will.payload.count + 2
        }
        // user name
        if let username {
            size += username.utf8.count + 2
        }
        // password
        if let password {
            size += password.utf8.count + 2
        }
        return size
    }
}

struct PublishPacket: Packet {
    enum Flags {
        static let duplicate: UInt8 = 8
        static let retain: UInt8 = 1
        static let qosShift: UInt8 = 1
        static let qosMask: UInt8 = 6
    }

    var type: PacketType { .PUBLISH }
    var description: String { "PUBLISH" }
    
    let id: UInt16
    let message: MQTT.Message

    func write(version: MQTT.Version, to byteBuffer: inout DataBuffer) throws {
        var flags: UInt8 = self.message.retain ? Flags.retain : 0
        flags |= self.message.qos.rawValue << Flags.qosShift
        flags |= self.message.dup ? Flags.duplicate : 0

        writeFixedHeader(packetType: .PUBLISH, flags: flags, size: self.packetSize(version: version), to: &byteBuffer)
        // write variable header
        try Serializer.writeString(self.message.topic, to: &byteBuffer)
        if self.message.qos != .atMostOnce {
            byteBuffer.writeInteger(self.id)
        }
        // v5 properties
        if version == .v5_0 {
            try self.message.properties.write(to: &byteBuffer)
        }
        // write payload
        byteBuffer.writeData(self.message.payload)
    }

    static func read(version: MQTT.Version, from packet: IncomingPacket) throws -> Self {
        var remainingData = packet.remainingData
        var packetId: UInt16 = 0
        // read topic name
        let topicName = try Serializer.readString(from: &remainingData)
        guard let qos = MQTTQoS(rawValue: (packet.flags & Flags.qosMask) >> Flags.qosShift) else { throw MQTTError.decodeError(.unexpectedTokens) }
        // read packet id if QoS is not atMostOnce
        if qos != .atMostOnce {
            guard let readPacketId: UInt16 = remainingData.readInteger() else { throw MQTTError.decodeError(.unexpectedTokens) }
            packetId = readPacketId
        }
        // read properties
        let properties: Properties
        if version == .v5_0 {
            properties = try Properties.read(from: &remainingData)
        } else {
            properties = .init()
        }

        // read payload
        let payload = remainingData.readData(length: remainingData.readableBytes) ?? Data()
        // create publish info
        let message = MQTT.Message(
            qos: qos,
            dup: packet.flags & Flags.duplicate != 0,
            topic: topicName,
            retain: packet.flags & Flags.retain != 0,
            payload: payload,
            properties: properties
        )
        return PublishPacket(id: packetId,message: message)
    }

    /// calculate size of publish packet
    func packetSize(version: MQTT.Version) -> Int {
        // topic name
        var size = self.message.topic.utf8.count
        if self.message.qos != .atMostOnce {
            size += 2
        }
        // packet identifier
        size += 2
        // properties
        if version == .v5_0 {
            let propertiesPacketSize = self.message.properties.packetSize
            size += Serializer.varintPacketSize(propertiesPacketSize) + propertiesPacketSize
        }
        // payload
        size += self.message.payload.count
        return size
    }
}

struct SubscribePacket: Packet {
    enum Flags {
        static let qosMask: UInt8 = 3
        static let noLocal: UInt8 = 4
        static let retainAsPublished: UInt8 = 8
        static let retainHandlingShift: UInt8 = 4
        static let retainHandlingMask: UInt8 = 48
    }

    var type: PacketType { .SUBSCRIBE }
    var description: String { "SUBSCRIBE" }
    let id: UInt16
    let subscriptions: [Subscribe.V5]
    let properties: Properties?
    

    func write(version: MQTT.Version, to byteBuffer: inout DataBuffer) throws {
        writeFixedHeader(packetType: .SUBSCRIBE, size: self.packetSize(version: version), to: &byteBuffer)
        // write variable header
        byteBuffer.writeInteger(self.id)
        // v5 properties
        if version == .v5_0 {
            let properties = self.properties ?? Properties()
            try properties.write(to: &byteBuffer)
        }
        // write payload
        for info in self.subscriptions {
            try Serializer.writeString(info.topicFilter, to: &byteBuffer)
            switch version {
            case .v3_1_1:
                byteBuffer.writeInteger(info.qos.rawValue)
            case .v5_0:
                var flags = info.qos.rawValue & Flags.qosMask
                flags |= info.noLocal ? Flags.noLocal : 0
                flags |= info.retainAsPublished ? Flags.retainAsPublished : 0
                flags |= (info.retainHandling.rawValue << Flags.retainHandlingShift) & Flags.retainHandlingMask
                byteBuffer.writeInteger(flags)
            }
        }
    }

    static func read(version: MQTT.Version, from packet: IncomingPacket) throws -> Self {
        throw MQTTError.noNeedImplemention
    }

    /// calculate size of subscribe packet
    func packetSize(version: MQTT.Version) -> Int {
        // packet identifier
        var size = 2
        // properties
        if version == .v5_0 {
            let propertiesPacketSize = self.properties?.packetSize ?? 0
            size += Serializer.varintPacketSize(propertiesPacketSize) + propertiesPacketSize
        }
        // payload
        return self.subscriptions.reduce(size) {
            $0 + 2 + $1.topicFilter.utf8.count + 1 // topic filter length + topic filter + qos
        }
    }
}

struct UnsubscribePacket: Packet {
    var type: PacketType { .UNSUBSCRIBE }
    var description: String { "UNSUBSCRIBE" }
    let id: UInt16
    let subscriptions: [String]
    let properties: Properties?
    func write(version: MQTT.Version, to byteBuffer: inout DataBuffer) throws {
        writeFixedHeader(packetType: .UNSUBSCRIBE, size: self.packetSize(version: version), to: &byteBuffer)
        // write variable header
        byteBuffer.writeInteger(self.id)
        // v5 properties
        if version == .v5_0 {
            let properties = self.properties ?? Properties()
            try properties.write(to: &byteBuffer)
        }
        // write payload
        for sub in self.subscriptions {
            try Serializer.writeString(sub, to: &byteBuffer)
        }
    }

    static func read(version: MQTT.Version, from packet: IncomingPacket) throws -> Self {
        throw MQTTError.noNeedImplemention
    }

    /// calculate size of subscribe packet
    func packetSize(version: MQTT.Version) -> Int {
        // packet identifier
        var size = 2
        // properties
        if version == .v5_0 {
            let propertiesPacketSize = self.properties?.packetSize ?? 0
            size += Serializer.varintPacketSize(propertiesPacketSize) + propertiesPacketSize
        }
        // payload
        return self.subscriptions.reduce(size) {
            $0 + 2 + $1.utf8.count // topic filter length + topic filter
        }
    }
}
/// `PUBACK` `PUBREC` `PUBREL` `PUBCOMP`
struct PubackPacket: Packet {
    var description: String { "\(self.type)(id:\(id),reason:\(reason))" }
    let type: PacketType
    let id: UInt16
    let reason: ResultCode.Puback
    let properties: Properties
    init(
        id: UInt16,
        type: PacketType,
        reason: ResultCode.Puback = .success,
        properties: Properties = .init()
    ) {
        self.type = type
        self.id = id
        self.reason = reason
        self.properties = properties
    }

    func write(version: MQTT.Version, to byteBuffer: inout DataBuffer) throws {
        writeFixedHeader(packetType: self.type, size: self.packetSize(version: version), to: &byteBuffer)
        byteBuffer.writeInteger(self.id)
        if version == .v5_0,
           self.reason != .success || self.properties.count > 0
        {
            byteBuffer.writeInteger(self.reason.rawValue)
            try self.properties.write(to: &byteBuffer)
        }
    }

    static func read(version: MQTT.Version, from packet: IncomingPacket) throws -> Self {
        var remainingData = packet.remainingData
        guard let packetId: UInt16 = remainingData.readInteger() else { throw MQTTError.decodeError(.unexpectedTokens) }
        switch version {
        case .v3_1_1:
            return PubackPacket(id:packetId, type: packet.type)
        case .v5_0:
            if remainingData.readableBytes == 0 {
                return PubackPacket(id: packetId, type: packet.type)
            }
            guard let reasonByte: UInt8 = remainingData.readInteger(),
                  let reason = ResultCode.Puback(rawValue: reasonByte)
            else {
                throw MQTTError.decodeError(.unexpectedTokens)
            }
            let properties = try Properties.read(from: &remainingData)
            return PubackPacket(id: packetId, type: packet.type, reason: reason, properties: properties)
        }
    }

    func packetSize(version: MQTT.Version) -> Int {
        if version == .v5_0,
           self.reason != .success || self.properties.count > 0
        {
            let propertiesPacketSize = self.properties.packetSize
            return 3 + Serializer.varintPacketSize(propertiesPacketSize) + propertiesPacketSize
        }
        return 2
    }
}

struct SubackPacket: Packet {
    var description: String { "\(self.type)(id:\(id),reason:\(reasons))" }
    let id: UInt16
    let type: PacketType
    let reasons: [ResultCode.Suback]
    let properties: Properties

    private init(id: UInt16,type: PacketType, reasons: [ResultCode.Suback], properties: Properties = .init()) {
        self.id = id
        self.type = type
        self.reasons = reasons
        self.properties = properties
    }

    func write(version: MQTT.Version, to byteBuffer: inout DataBuffer) throws {
        throw MQTTError.noNeedImplemention
    }

    static func read(version: MQTT.Version, from packet: IncomingPacket) throws -> Self {
        var remainingData = packet.remainingData
        guard let packetId: UInt16 = remainingData.readInteger() else { throw MQTTError.decodeError(.unexpectedTokens) }
        var properties: Properties
        if version == .v5_0 {
            properties = try Properties.read(from: &remainingData)
        } else {
            properties = .init()
        }
        var reasons: [ResultCode.Suback]?
        if let reasonBytes = remainingData.readData() {
            reasons = try reasonBytes.map { byte -> ResultCode.Suback in
                guard let reason = ResultCode.Suback(rawValue: byte) else {
                    throw MQTTError.decodeError(.unexpectedTokens)
                }
                return reason
            }
        }
        return SubackPacket(id:packetId,type: packet.type, reasons: reasons ?? [], properties: properties)
    }

    func packetSize(version: MQTT.Version) -> Int {
        if version == .v5_0 {
            let propertiesPacketSize = self.properties.packetSize
            return 2 + Serializer.varintPacketSize(propertiesPacketSize) + propertiesPacketSize
        }
        return 2
    }
}

struct PingreqPacket: Packet {
    var type: PacketType { .PINGREQ }
    var description: String { "PINGREQ" }
    func write(version: MQTT.Version, to byteBuffer: inout DataBuffer) throws {
        writeFixedHeader(packetType: .PINGREQ, size: self.packetSize, to: &byteBuffer)
    }
    static func read(version: MQTT.Version, from packet: IncomingPacket) throws -> Self {
        PingreqPacket()
    }
    var packetSize: Int { 0 }
}

struct PingrespPacket: Packet {
    var type: PacketType { .PINGRESP }
    var description: String { "PINGRESP" }
    func write(version: MQTT.Version, to byteBuffer: inout DataBuffer) throws {
        writeFixedHeader(packetType: .PINGRESP, size: self.packetSize, to: &byteBuffer)
    }
    static func read(version: MQTT.Version, from packet: IncomingPacket) throws -> Self {
        PingrespPacket()
    }
    var packetSize: Int { 0 }
}

struct DisconnectPacket: Packet {
    var type: PacketType { .DISCONNECT }
    var description: String { "DISCONNECT(reason:\(result))" }
    let result: ResultCode.Disconnect
    let properties: Properties
    init(result: ResultCode.Disconnect = .normal, properties: Properties = .init()) {
        self.result = result
        self.properties = properties
    }

    func write(version: MQTT.Version, to byteBuffer: inout DataBuffer) throws {
        writeFixedHeader(packetType: self.type, size: self.packetSize(version: version), to: &byteBuffer)
        if version == .v5_0,
           self.result != .normal || self.properties.count > 0
        {
            byteBuffer.writeInteger(self.result.rawValue)
            try self.properties.write(to: &byteBuffer)
        }
    }

    static func read(version: MQTT.Version, from packet: IncomingPacket) throws -> Self {
        var buffer = packet.remainingData
        switch version {
        case .v3_1_1:
            return DisconnectPacket()
        case .v5_0:
            if buffer.readableBytes == 0 {
                return DisconnectPacket(result: .normal)
            }
            guard let reasonByte: UInt8 = buffer.readInteger(), let result = ResultCode.Disconnect(rawValue: reasonByte) else {
                throw MQTTError.decodeError(.unexpectedTokens)
            }
            let properties = try Properties.read(from: &buffer)
            return DisconnectPacket(result: result, properties: properties)
        }
    }

    func packetSize(version: MQTT.Version) -> Int {
        if version == .v5_0, self.result != .normal || self.properties.count > 0{
            let propertiesPacketSize = self.properties.packetSize
            return 1 + Serializer.varintPacketSize(propertiesPacketSize) + propertiesPacketSize
        }
        return 0
    }
}

struct ConnackPacket: Packet {
    var type: PacketType { .CONNACK }
    var description: String { "CONNACK(code:\(returnCode),flags:\(acknowledgeFlags))" }
    let returnCode: UInt8
    let acknowledgeFlags: UInt8
    let properties: Properties
    var sessionPresent: Bool { self.acknowledgeFlags & 0x1 == 0x1 }
    func write(version: MQTT.Version, to: inout DataBuffer) throws {
        throw MQTTError.noNeedImplemention
    }
    static func read(version: MQTT.Version, from packet: IncomingPacket) throws -> Self {
        var remainingData = packet.remainingData
        guard let bytes = remainingData.readData(length: 2) else { throw MQTTError.decodeError(.unexpectedTokens) }
        let properties: Properties
        if version == .v5_0 {
            properties = try Properties.read(from: &remainingData)
        } else {
            properties = .init()
        }
        return ConnackPacket(
            returnCode: bytes[1],
            acknowledgeFlags: bytes[0],
            properties: properties
        )
    }
}

struct AuthPacket: Packet {
    var type: PacketType { .AUTH }
    var description: String { "AUTH(reason:\(reason))" }
    let reason: ResultCode.Auth
    let properties: Properties
    func write(version: MQTT.Version, to byteBuffer: inout DataBuffer) throws {
        writeFixedHeader(packetType: self.type, size: self.packetSize, to: &byteBuffer)
        if self.reason != .success || self.properties.count > 0 {
            byteBuffer.writeInteger(self.reason.rawValue)
            try self.properties.write(to: &byteBuffer)
        }
    }
    static func read(version: MQTT.Version, from packet: IncomingPacket) throws -> Self {
        var remainingData = packet.remainingData
        // if no data attached then can assume success
        if remainingData.readableBytes == 0 {
            return AuthPacket(reason: .success, properties: .init())
        }
        guard let reasonByte: UInt8 = remainingData.readInteger(),
              let reason = ResultCode.Auth(rawValue: reasonByte)
        else {
            throw MQTTError.decodeError(.unexpectedTokens)
        }
        let properties = try Properties.read(from: &remainingData)
        return AuthPacket(reason: reason, properties: properties)
    }
    var packetSize: Int {
        if self.reason == .success, self.properties.count == 0 {
            return 0
        }
        let propertiesPacketSize = self.properties.packetSize
        return 1 + Serializer.varintPacketSize(propertiesPacketSize) + propertiesPacketSize
    }
}

/// MQTT incoming packet parameters.
struct IncomingPacket {
    var description: String { "Incoming Packet 0x\(String(format: "%x", self.type.rawValue))" }
    /// Type of incoming MQTT packet.
    let type: PacketType
    /// packet flags
    let flags: UInt8
    /// Remaining serialized data in the MQTT packet.
    let remainingData: DataBuffer
    func write(version: MQTT.Version, to byteBuffer: inout DataBuffer) throws {
//        writeFixedHeader(packetType: self.type, flags: self.flags, size: self.remainingData.readableBytes, to: &byteBuffer)
        var buffer = self.remainingData
        byteBuffer.writeBuffer(&buffer)
    }
    static func read(version: MQTT.Version, from packet: IncomingPacket) throws -> Self {
        throw MQTTError.noNeedImplemention
    }
    /// read incoming packet
    ///
    /// read fixed header and data attached. Throws incomplete packet error if if cannot read
    /// everything
    static func read(from byteBuffer: inout DataBuffer) throws -> IncomingPacket {
        guard let byte: UInt8 = byteBuffer.readInteger() else { throw MQTTError.incompletePacket }
        guard let type = PacketType(rawValue: byte) ?? PacketType(rawValue: byte & 0xF0) else {
            throw MQTTError.decodeError(.unrecognisedPacketType)
        }
        let length = try Serializer.readVarint(from: &byteBuffer)
        guard let buffer = byteBuffer.readBuffer(length: length) else { throw MQTTError.incompletePacket }
        return IncomingPacket(type: type, flags: byte & 0xF, remainingData: buffer)
    }
    func packet(with version:MQTT.Version)throws -> Packet{
        switch self.type {
        case .PUBLISH:
            return try PublishPacket.read(version: version, from: self)
        case .CONNACK:
            return try ConnackPacket.read(version: version, from: self)
        case .PUBACK, .PUBREC, .PUBREL, .PUBCOMP:
            return try PubackPacket.read(version: version, from: self)
        case .SUBACK, .UNSUBACK:
            return try SubackPacket.read(version: version, from: self)
        case .PINGREQ:
            return try PingreqPacket.read(version: version, from: self)
        case .PINGRESP:
            return try PingrespPacket.read(version: version, from: self)
        case .DISCONNECT:
            return try DisconnectPacket.read(version: version, from: self)
        case .AUTH:
            return try AuthPacket.read(version: version, from: self)
        case .CONNECT,.SUBSCRIBE,.UNSUBSCRIBE:
            throw MQTTError.noNeedImplemention
        }
    }
}
