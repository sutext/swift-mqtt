//
//  MQTTClient.swift
//  MQTTDemo
//
//  Created by supertext on 2024/12/11.
//

import MQTTNIO
import MQTT
import CocoaMQTT
import Foundation
import Network

let client = MQTTClient()
//let mqtt = {
//    let m = CocoaMQTT5(clientID: "swift-mqtt", host: "broker.beta.jagat.io", port: 1883)
//    m.connectProperties = MqttConnectProperties()
//    m.connectProperties?.topicAliasMaximum = 0
//    m.username = "jagat-mqtt-pwd-im"
//    m.password = "jagat-mqtt-pwd-im"
//    m.cleanSession = true
//    m.logLevel = .debug
//    m.delegate = client
//    return m
//}()
let mqtt = {
    let params = NWParameters.tls
    let endpoint = NWEndpoint.hostPort(host: "broker.beta.jagat.io", port: 1883)
    let m = MQTT("swift-mqtt", endpoint: endpoint, params: .tcp)
    m.config.username = "jagat-mqtt-pwd-im"
    m.config.password = "jagat-mqtt-pwd-im"
    m.config.cleanSession = true
    m.usingMonitor()
    m.usingRetrier()
    MQTT.logLevel = .debug
    return m
}()
//let mqtt = {
//    let params = NWParameters.tls
//    let endpoint = NWEndpoint.hostPort(host: "broker.beta.jagat.io", port: 1883)
//    let m = MQTTNIO.MQTTClient(host: "broker.beta.jagat.io", port: 1883, identifier: "swift-mqtt", eventLoopGroupProvider: .createNew, logger: .init(label: "MQTT"),configuration: .init(version: .v5_0,userName: "jagat-mqtt-pwd-im",password: "jagat-mqtt-pwd-im"))
//    return m
//}()
extension MQTTNIO.MQTTClient{
    func open(){
        _ = self.connect(cleanSession: true,will: nil)
    }
    func close(){
        _ = self.disconnect()
    }
    func publish(_ topic:String,payload:String){
        _ = self.publish(to: topic, payload: .init(string: payload), qos: .atLeastOnce)
    }
    func subscribe(_ topic:String){
        _ = self.subscribe(to: [.init(topicFilter: topic, qos: .atLeastOnce)])
    }
    func unsubscribe(_ topic:String){
        _ = self.unsubscribe(from: [topic])
    }
}
extension MQTT{
    func open(){
        self.v5.connect()
    }
    func close(){
        self.v5.close()
    }
    func publish(_ topic:String,payload:String){
        self.v5.publish(topic, payload: payload)
    }
    func subscribe(_ topic:String){
        self.v5.subscribe(topic)
    }
    func unsubscribe(_ topic:String){
        self.v5.unsubscribe(topic)
    }
}
extension CocoaMQTT5{
    func open(){
       _ = self.connect()
    }
    func close(){
        self.disconnect()
    }
}
class MQTTClient{

}
extension MQTTClient:CocoaMQTT5Delegate{
    func mqtt5(_ mqtt5: CocoaMQTT5, didConnectAck ack: CocoaMQTTCONNACKReasonCode, connAckData: MqttDecodeConnAck?) {
        
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishMessage message: CocoaMQTT5Message, id: UInt16) {
        
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishAck id: UInt16, pubAckData: MqttDecodePubAck?) {
        
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishRec id: UInt16, pubRecData: MqttDecodePubRec?) {
        
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveMessage message: CocoaMQTT5Message, id: UInt16, publishData: MqttDecodePublish?) {
        
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didSubscribeTopics success: NSDictionary, failed: [String], subAckData: MqttDecodeSubAck?) {
        
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didUnsubscribeTopics topics: [String], unsubAckData: MqttDecodeUnsubAck?) {
        
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveDisconnectReasonCode reasonCode: CocoaMQTTDISCONNECTReasonCode) {
        
    }
    
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveAuthReasonCode reasonCode: CocoaMQTTAUTHReasonCode) {
        
    }
    
    func mqtt5DidPing(_ mqtt5: CocoaMQTT5) {
        
    }
    
    func mqtt5DidReceivePong(_ mqtt5: CocoaMQTT5) {
        
    }
    
    func mqtt5DidDisconnect(_ mqtt5: CocoaMQTT5, withError err: (any Error)?) {
        
    }
}
