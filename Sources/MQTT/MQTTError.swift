//
//  MQTTError.swift
//  swift-mqtt
//
//  Created by supertext on 2024/12/20.
//

import Foundation
import Network


/// MQTTClient errors
public enum MQTTError:Sendable,Equatable, Swift.Error {
    /// You called connect on a client that is already connected to the broker
    case alreadyConnected
    /// You called connect on a client that is already connected to the broker
    case alreadyConnecting
    /// Client has already been shutdown
    case alreadyShutdown
    /// We received an unexpected message while connecting
    case failedToConnect
    /// We received an unsuccessful connection return value only v5
    case connectFailV3(ResultCode.ConnectV3)
    /// We received an unsuccessful connection return value only v5
    case connectFailV5(ResultCode.ConnectV5)
    /// We received an unsuccessful return value from either a connect or publish
    case reasonError(ResultCode)
    /// client in not connected
    case noConnection
    /// the server disconnected
    case serverDisconnection(ResultCode.Disconnect)
    /// the server closed the connection. If this happens during a publish you can resend
    /// the publish packet by reconnecting to server with `cleanSession` set to false.
    case serverClosedConnection
    /// received unexpected message from broker
    case unexpectedMessage
    /// Encode of MQTT packet error or invalid paarameters
    case packetError(Packet)
    /// Decode of MQTT message failed
    case decodeError(Decode)
    /// client timed out while waiting for response from server
    case timeout
    /// Auth packets sent without authWorkflow being supplied
    case authflowRequired
    /// Packet error incomplete packet
    case incompletePacket
    /// never happen forever
    case noNeedImplemention
}
extension MQTTError{
    /// Errors generated by bad packets sent by the client
    public enum Packet:Sendable,Equatable {
        case badParameter
        /// Packet sent contained invalid entries
        /// QoS is not accepted by this connection as it is greater than the accepted value
        case qosInvalid
        /// publish messages on this connection do not support the retain flag
        case retainUnavailable
        /// subscribe/unsubscribe packet requires at least one topic
        case atLeastOneTopicRequired
        /// topic alias is greater than server maximum topic alias or the alias is zero
        case topicAliasOutOfRange
        /// invalid topic name
        case invalidTopicName
        /// client to server publish packets cannot include a subscription identifier
        case publishIncludesSubscription
    }
}


extension MQTTError{
    public enum Decode:Sendable,Equatable{
        /// some network error
        case networkError(_ error:NWError)
        /// Read variable length overflow
        case varintOverflow
        /// Packet received contained invalid tokens
        case unexpectedTokens
        /// got unexpected data length when read
        case unexpectedDataLength
        /// Failed to recognise the packet control type
        case unrecognisedPacketType
    }
}
