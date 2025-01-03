//
//  MQTTError.swift
//  swift-mqtt
//
//  Created by supertext on 2024/12/20.
//

import Foundation
import Network


/// MQTTClient errors
public enum MQError:Sendable,Equatable, Swift.Error {
    /// You called connect on a client that is already connected to the broker
    case alreadyConnected
    /// You called connect on a client that is already connected to the broker
    case alreadyConnecting
    /// Client has already been shutdown
    case alreadyShutdown
    /// We received an unexpected message while connecting
    case failedToConnect
    /// We received an unsuccessful connection return value
    case connectionError(ConnectRetrunCode)
    /// We received an unsuccessful return value from either a connect or publish
    case reasonError(ReasonCode)
    /// client in not connected
    case noConnection
    /// the server disconnected
    case serverDisconnection(AckV5)
    /// the server closed the connection. If this happens during a publish you can resend
    /// the publish packet by reconnecting to server with `cleanSession` set to false.
    case serverClosedConnection
    /// received unexpected message from broker
    case unexpectedMessage
    /// Decode of MQTT message failed
    case decodeError
    /// client timed out while waiting for response from server
    case timeout
    /// Internal error, used to get the client to retry sending
    case retrySend
    /// You have provided the wrong TLS configuration for the EventLoopGroup you provided
    case wrongTLSConfig
    /// Packet received contained invalid entries
    case badResponse
    /// Failed to recognise the packet control type
    case unrecognisedPacketType
    /// Auth packets sent without authWorkflow being supplied
    case authflowRequired
}
/// Errors generated by bad packets sent by the client
public enum PacketError:Sendable,Equatable,Swift.Error {
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

public enum DecodeError:Sendable,Equatable,Swift.Error{
    /// Read variable length overflow
    case varintOverflow
    /// some network error
    case networkError(_ error:NWError)
    /// got unexpected data length when read
    case unexpectedDataLength
    /// Failed to recognise the packet control type
    case unrecognisedPacketType
}