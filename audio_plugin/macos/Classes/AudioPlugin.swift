import Cocoa
import CoreAudio
import AudioToolbox
import FlutterMacOS
import os

// MARK: - DeviceListener Protocol and Class

protocol DeviceListenerDelegate: AnyObject {
  func deviceWasConnected(uid: String, name: String)
  func deviceWasDisconnected(uid: String, name: String)
}

private final class DeviceListener {
  weak var delegate: DeviceListenerDelegate?
  
  private var knownDeviceUIDs: Set<String> = []
  private var deviceNames: [String: String] = [:]
  private var isListening = false
  private var listenerBlock: AudioObjectPropertyListenerBlock?
  private let listenerQueue = DispatchQueue(label: "com.violetpatch.devicelistener", qos: .userInitiated)
  
  init() {
    // Initialize with current devices
    refreshKnownDevices()
  }
  
  func start() {
    guard !isListening else { return }
    
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    
    listenerBlock = { [weak self] (numberAddresses: UInt32, addresses: UnsafePointer<AudioObjectPropertyAddress>) in
      self?.handleDeviceListChange()
    }
    
    guard let block = listenerBlock else { return }
    
    let status = AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      listenerQueue,
      block
    )
    
    if status == noErr {
      isListening = true
    }
  }
  
  func stop() {
    guard isListening else { return }
    
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    
    if let block = listenerBlock {
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        listenerQueue,
        block
      )
    }
    
    listenerBlock = nil
    isListening = false
  }
  
  private func refreshKnownDevices() {
    let currentDevices = getCurrentDevices()
    knownDeviceUIDs = Set(currentDevices.keys)
    deviceNames = currentDevices
  }
  
  private func handleDeviceListChange() {
    let currentDevices = getCurrentDevices()
    let currentUIDs = Set(currentDevices.keys)
    
    // Find disconnected devices
    let disconnected = knownDeviceUIDs.subtracting(currentUIDs)
    for uid in disconnected {
      let name = deviceNames[uid] ?? "Unknown Device"
      DispatchQueue.main.async { [weak self] in
        self?.delegate?.deviceWasDisconnected(uid: uid, name: name)
      }
    }
    
    // Find connected devices
    let connected = currentUIDs.subtracting(knownDeviceUIDs)
    for uid in connected {
      let name = currentDevices[uid] ?? "Unknown Device"
      DispatchQueue.main.async { [weak self] in
        self?.delegate?.deviceWasConnected(uid: uid, name: name)
      }
    }
    
    // Update known devices
    knownDeviceUIDs = currentUIDs
    deviceNames = currentDevices
  }
  
  private func getCurrentDevices() -> [String: String] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    
    var dataSize: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr else {
      return [:]
    }
    
    let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = Array<AudioDeviceID>(repeating: 0, count: count)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs) == noErr else {
      return [:]
    }
    
    var devices: [String: String] = [:]
    for deviceID in deviceIDs {
      if let uid = getDeviceUID(deviceID), let name = getDeviceName(deviceID) {
        devices[uid] = name
      }
    }
    return devices
  }
  
  private func getDeviceUID(_ deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    var dataSize = UInt32(MemoryLayout<CFString>.size)
    var uid: CFString = "" as CFString
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &uid)
    return status == noErr ? uid as String : nil
  }
  
  private func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioObjectPropertyName,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    var dataSize = UInt32(MemoryLayout<CFString>.size)
    var name: CFString = "" as CFString
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &name)
    return status == noErr ? name as String : nil
  }
  
  deinit {
    stop()
  }
}

// MARK: - AudioPlugin

public class AudioPlugin: NSObject, FlutterPlugin, DeviceListenerDelegate {
  private let engine = AudioRouterEngine()
  private let deviceListener = DeviceListener()
  private var deviceEventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "audio_plugin", binaryMessenger: registrar.messenger)
    let instance = AudioPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    // Register EventChannel for device events
    let eventChannel = FlutterEventChannel(name: "audio_plugin/device_events", binaryMessenger: registrar.messenger)
    eventChannel.setStreamHandler(instance)
  }
  
  override init() {
    super.init()
    deviceListener.delegate = self
    deviceListener.start()
  }
  
  // MARK: - DeviceListenerDelegate
  
  func deviceWasConnected(uid: String, name: String) {
    let event: [String: Any] = [
      "type": "connected",
      "uid": uid,
      "name": name
    ]
    deviceEventSink?(event)
  }
  
  func deviceWasDisconnected(uid: String, name: String) {
    let event: [String: Any] = [
      "type": "disconnected",
      "uid": uid,
      "name": name
    ]
    deviceEventSink?(event)
    
    // Notify engine about disconnection for graceful handling
    engine.handleDeviceDisconnected(uid: uid)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "listDevices":
      result(listDevices())
    case "getDefaultDevices":
      result(getDefaultDevices())
    case "startSession":
      handleStartSession(call, result: result)
    case "stopSession":
      engine.stop()
      result(nil)
    case "getStats":
      result(engine.stats())
    case "addRoute":
      handleAddRoute(call, result: result)
    case "removeRoute":
      handleRemoveRoute(call, result: result)
    case "setRouteEnabled":
      handleSetRouteEnabled(call, result: result)
    case "setRouteGain":
      handleSetRouteGain(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleStartSession(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_args", message: "Missing session options", details: nil))
      return
    }

    guard let outputUID = args["outputDeviceUID"] as? String, !outputUID.isEmpty else {
      result(FlutterError(code: "invalid_output_uid", message: "outputDeviceUID is required", details: nil))
      return
    }

    let sampleRate = (args["sampleRate"] as? NSNumber)?.doubleValue ?? 48000
    let bufferFrames = (args["bufferFrames"] as? NSNumber)?.uint32Value ?? 256

    if Int(sampleRate) != 48000 {
      result(FlutterError(code: "unsupported_sample_rate", message: "Only 48kHz is supported in MVP", details: nil))
      return
    }

    guard let deviceID = AudioDeviceCatalog.deviceID(forUID: outputUID) else {
      result(FlutterError(code: "device_not_found", message: "Output device not found", details: outputUID))
      return
    }

    if !AudioDeviceCatalog.supportsSampleRate(deviceID, sampleRate: sampleRate) {
      result(FlutterError(code: "sample_rate_not_supported", message: "Output device does not support 48kHz", details: outputUID))
      return
    }

    if !AudioDeviceCatalog.setSampleRate(deviceID, sampleRate: sampleRate) {
      result(FlutterError(code: "sample_rate_set_failed", message: "Failed to set sample rate", details: outputUID))
      return
    }

    if !AudioDeviceCatalog.setBufferFrames(deviceID, bufferFrames: bufferFrames) {
      result(FlutterError(code: "buffer_set_failed", message: "Failed to set buffer size", details: outputUID))
      return
    }

    let actualSampleRate = Int(AudioDeviceCatalog.currentSampleRate(deviceID))
    let actualBufferFrames = Int(AudioDeviceCatalog.currentBufferFrames(deviceID))

    let session = engine.start(outputUID: outputUID, sampleRate: actualSampleRate, bufferFrames: actualBufferFrames)
    result(session)
  }

  private func handleAddRoute(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_args", message: "Missing route", details: nil))
      return
    }

    if let error = engine.addRoute(args: args) {
      result(error)
      return
    }
    result(nil)
  }

  private func handleRemoveRoute(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let routeId = args["id"] as? String else {
      result(FlutterError(code: "invalid_args", message: "Missing route id", details: nil))
      return
    }

    engine.removeRoute(id: routeId)
    result(nil)
  }

  private func handleSetRouteEnabled(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let routeId = args["id"] as? String,
          let enabled = args["enabled"] as? Bool else {
      result(FlutterError(code: "invalid_args", message: "Missing route enabled", details: nil))
      return
    }

    engine.setRouteEnabled(id: routeId, enabled: enabled)
    result(nil)
  }

  private func handleSetRouteGain(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let routeId = args["id"] as? String,
          let gain = args["gain"] as? NSNumber else {
      result(FlutterError(code: "invalid_args", message: "Missing route gain", details: nil))
      return
    }

    engine.setRouteGain(id: routeId, gain: gain.doubleValue)
    result(nil)
  }

  private func listDevices() -> [[String: Any]] {
    let devices = AudioDeviceCatalog.listDevices()
    return devices.map { device in
      return [
        "uid": device.uid,
        "name": device.name,
        "inputChannels": device.inputChannels,
        "outputChannels": device.outputChannels,
        "sampleRates": device.sampleRates,
        "isInput": device.inputChannels > 0,
        "isOutput": device.outputChannels > 0
      ]
    }
  }

  private func getDefaultDevices() -> [String: Any] {
    let defaults = AudioDeviceCatalog.defaultDevices()
    return [
      "defaultInputUID": defaults.inputUID,
      "defaultOutputUID": defaults.outputUID
    ]
  }
}

// MARK: - FlutterStreamHandler

extension AudioPlugin: FlutterStreamHandler {
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    deviceEventSink = events
    return nil
  }
  
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    deviceEventSink = nil
    return nil
  }
}

private struct AudioDeviceInfo {
  let uid: String
  let name: String
  let inputChannels: Int
  let outputChannels: Int
  let sampleRates: [Int]
}

private struct DefaultDeviceInfo {
  let inputUID: String
  let outputUID: String
}

private enum AudioDeviceCatalog {
  static func listDevices() -> [AudioDeviceInfo] {
    let deviceIDs = allDeviceIDs()
    return deviceIDs.compactMap { deviceID in
      guard let uid = deviceUID(deviceID) else { return nil }
      let name = deviceName(deviceID) ?? "Unknown"
      let inputChannels = channelCount(deviceID, scope: kAudioObjectPropertyScopeInput)
      let outputChannels = channelCount(deviceID, scope: kAudioObjectPropertyScopeOutput)
      let sampleRates = supportedSampleRates(deviceID)
      return AudioDeviceInfo(
        uid: uid,
        name: name,
        inputChannels: inputChannels,
        outputChannels: outputChannels,
        sampleRates: sampleRates
      )
    }
  }

  static func defaultDevices() -> DefaultDeviceInfo {
    let inputID = defaultDeviceID(selector: kAudioHardwarePropertyDefaultInputDevice)
    let outputID = defaultDeviceID(selector: kAudioHardwarePropertyDefaultOutputDevice)
    return DefaultDeviceInfo(
      inputUID: deviceUID(inputID) ?? "",
      outputUID: deviceUID(outputID) ?? ""
    )
  }

  static func deviceID(forUID uid: String) -> AudioDeviceID? {
    for deviceID in allDeviceIDs() {
      if deviceUID(deviceID) == uid {
        return deviceID
      }
    }
    return nil
  }

  static func supportsSampleRate(_ deviceID: AudioDeviceID, sampleRate: Double) -> Bool {
    let ranges = sampleRateRanges(deviceID)
    return ranges.contains { range in
      sampleRate >= range.mMinimum && sampleRate <= range.mMaximum
    }
  }

  static func setSampleRate(_ deviceID: AudioDeviceID, sampleRate: Double) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyNominalSampleRate,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    var rate = sampleRate
    let dataSize = UInt32(MemoryLayout<Double>.size)
    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, dataSize, &rate)
    return status == noErr
  }

  static func setBufferFrames(_ deviceID: AudioDeviceID, bufferFrames: UInt32) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyBufferFrameSize,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    var frames = bufferFrames
    let dataSize = UInt32(MemoryLayout<UInt32>.size)
    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, dataSize, &frames)
    return status == noErr
  }

  static func currentSampleRate(_ deviceID: AudioDeviceID) -> Double {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyNominalSampleRate,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    var rate = Double(0)
    var dataSize = UInt32(MemoryLayout<Double>.size)
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &rate)
    return status == noErr ? rate : 0
  }

  static func currentBufferFrames(_ deviceID: AudioDeviceID) -> UInt32 {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyBufferFrameSize,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    var frames = UInt32(0)
    var dataSize = UInt32(MemoryLayout<UInt32>.size)
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &frames)
    return status == noErr ? frames : 0
  }

  static func inputChannelCount(_ deviceID: AudioDeviceID) -> Int {
    return channelCount(deviceID, scope: kAudioObjectPropertyScopeInput)
  }

  static func outputChannelCount(_ deviceID: AudioDeviceID) -> Int {
    return channelCount(deviceID, scope: kAudioObjectPropertyScopeOutput)
  }

  private static func allDeviceIDs() -> [AudioDeviceID] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    var dataSize: UInt32 = 0
    let status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
    guard status == noErr else { return [] }
    let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = Array<AudioDeviceID>(repeating: 0, count: count)
    let statusData = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs)
    guard statusData == noErr else { return [] }
    return deviceIDs
  }

  private static func deviceName(_ deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioObjectPropertyName,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    var dataSize = UInt32(MemoryLayout<CFString>.size)
    var name: CFString = "" as CFString
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &name)
    return status == noErr ? name as String : nil
  }

  private static func deviceUID(_ deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    var dataSize = UInt32(MemoryLayout<CFString>.size)
    var uid: CFString = "" as CFString
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &uid)
    return status == noErr ? uid as String : nil
  }

  private static func channelCount(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamConfiguration,
      mScope: scope,
      mElement: kAudioObjectPropertyElementMaster
    )
    var dataSize: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else { return 0 }
    let bufferPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { bufferPointer.deallocate() }
    let audioBufferList = bufferPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, audioBufferList) == noErr else { return 0 }
    let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
    return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
  }

  private static func sampleRateRanges(_ deviceID: AudioDeviceID) -> [AudioValueRange] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyAvailableNominalSampleRates,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    var dataSize: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else { return [] }
    let count = Int(dataSize) / MemoryLayout<AudioValueRange>.size
    var ranges = Array<AudioValueRange>(repeating: AudioValueRange(mMinimum: 0, mMaximum: 0), count: count)
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &ranges) == noErr else { return [] }
    return ranges
  }

  private static func supportedSampleRates(_ deviceID: AudioDeviceID) -> [Int] {
    let ranges = sampleRateRanges(deviceID)
    var rates = Set<Int>()
    let commonRates: [Double] = [44100, 48000]
    for candidate in commonRates {
      if ranges.contains(where: { candidate >= $0.mMinimum && candidate <= $0.mMaximum }) {
        rates.insert(Int(candidate))
      }
    }
    if rates.isEmpty {
      for range in ranges {
        rates.insert(Int(range.mMinimum))
        rates.insert(Int(range.mMaximum))
      }
    }
    return rates.sorted()
  }

  private static func defaultDeviceID(selector: AudioObjectPropertySelector) -> AudioDeviceID {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )
    var deviceID = AudioDeviceID(0)
    var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID)
    return status == noErr ? deviceID : AudioDeviceID(0)
  }
}

private struct Route {
  let id: String
  let inDeviceUID: String
  let outDeviceUID: String
  var inL: Int
  var inR: Int
  var outL: Int
  var outR: Int
  var gain: Double
  var enabled: Bool
}

private struct ReadWindow {
  let startFrame: Int64
  let frames: Int
  let underrun: Bool
  let overrun: Bool
}

private final class RingBuffer {
  let channels: Int
  let capacityFrames: Int
  private var buffers: [[Float]]
  private var writeFrame: Int64 = 0
  private var readerFrames: [String: Int64] = [:]
  private var lock = os_unfair_lock_s()

  init(channels: Int, capacityFrames: Int) {
    self.channels = channels
    self.capacityFrames = max(1, capacityFrames)
    self.buffers = Array(
      repeating: Array(repeating: 0, count: self.capacityFrames),
      count: channels
    )
  }

  func registerReader(_ readerId: String) {
    os_unfair_lock_lock(&lock)
    if readerFrames[readerId] == nil {
      // Start reader slightly behind writeFrame to ensure data is available
      // Use half the buffer capacity as initial latency
      let initialOffset = Int64(capacityFrames / 2)
      let startPosition = max(0, writeFrame - initialOffset)
      readerFrames[readerId] = startPosition
    }
    os_unfair_lock_unlock(&lock)
  }

  func pruneReaders(keeping readerIds: Set<String>) {
    os_unfair_lock_lock(&lock)
    readerFrames = readerFrames.filter { readerIds.contains($0.key) }
    os_unfair_lock_unlock(&lock)
  }

  func write(from bufferList: UnsafeMutableAudioBufferListPointer, frames: Int) {
    if frames <= 0 || channels == 0 {
      return
    }
    os_unfair_lock_lock(&lock)
    let capacity = capacityFrames
    let writeCount = min(frames, capacity)
    let skip = frames - writeCount
    let startFrame = writeFrame + Int64(skip)
    for channel in 0..<channels {
      guard channel < bufferList.count else { continue }
      let buffer = bufferList[channel]
      guard let mData = buffer.mData else { continue }
      let source = mData.assumingMemoryBound(to: Float.self).advanced(by: skip)
      buffers[channel].withUnsafeMutableBufferPointer { destPtr in
        guard let destBase = destPtr.baseAddress else { return }
        var remaining = writeCount
        var destIndex = Int(startFrame % Int64(capacity))
        var srcIndex = 0
        while remaining > 0 {
          let chunk = min(remaining, capacity - destIndex)
          memcpy(
            destBase.advanced(by: destIndex),
            source.advanced(by: srcIndex),
            chunk * MemoryLayout<Float>.size
          )
          remaining -= chunk
          srcIndex += chunk
          destIndex = 0
        }
      }
    }
    writeFrame += Int64(frames)
    os_unfair_lock_unlock(&lock)
  }

  func beginRead(readerId: String, frames: Int) -> ReadWindow {
    if frames <= 0 {
      return ReadWindow(startFrame: 0, frames: 0, underrun: false, overrun: false)
    }
    os_unfair_lock_lock(&lock)
    
    // If reader not registered, register it now
    if readerFrames[readerId] == nil {
      let initialOffset = Int64(capacityFrames / 2)
      let startPosition = max(0, writeFrame - initialOffset)
      readerFrames[readerId] = startPosition
    }
    
    var readFrame = readerFrames[readerId]!
    var overrun = false
    let available = writeFrame - readFrame
    if available > Int64(capacityFrames) {
      readFrame = writeFrame - Int64(capacityFrames)
      readerFrames[readerId] = readFrame
      overrun = true
    }
    let currentAvailable = writeFrame - readFrame
    let framesToRead = min(frames, max(0, Int(currentAvailable)))
    let underrun = framesToRead < frames
    os_unfair_lock_unlock(&lock)
    return ReadWindow(
      startFrame: readFrame,
      frames: framesToRead,
      underrun: underrun,
      overrun: overrun
    )
  }

  func readChannel(
    readerId: String,
    startFrame: Int64,
    frames: Int,
    channel: Int,
    into destination: UnsafeMutablePointer<Float>
  ) {
    if frames <= 0 || channel >= channels {
      return
    }
    os_unfair_lock_lock(&lock)
    let capacity = capacityFrames
    let startIndex = Int(startFrame % Int64(capacity))
    buffers[channel].withUnsafeBufferPointer { srcPtr in
      guard let srcBase = srcPtr.baseAddress else { return }
      var remaining = frames
      var destIndex = 0
      var srcIndex = startIndex
      while remaining > 0 {
        let chunk = min(remaining, capacity - srcIndex)
        memcpy(
          destination.advanced(by: destIndex),
          srcBase.advanced(by: srcIndex),
          chunk * MemoryLayout<Float>.size
        )
        remaining -= chunk
        destIndex += chunk
        srcIndex = 0
      }
    }
    os_unfair_lock_unlock(&lock)
  }

  func endRead(readerId: String, frames: Int) {
    if frames <= 0 {
      return
    }
    os_unfair_lock_lock(&lock)
    let current = readerFrames[readerId] ?? writeFrame
    readerFrames[readerId] = current + Int64(frames)
    os_unfair_lock_unlock(&lock)
  }

  func fillRatio(readerId: String) -> Double {
    os_unfair_lock_lock(&lock)
    let readFrame = readerFrames[readerId] ?? writeFrame
    let available = writeFrame - readFrame
    let ratio = Double(max(0, min(available, Int64(capacityFrames)))) / Double(capacityFrames)
    os_unfair_lock_unlock(&lock)
    return ratio
  }
}

private final class InputTap {
  let deviceUID: String
  let deviceID: AudioDeviceID
  let channels: Int
  let sampleRate: Double
  let bufferFrames: UInt32
  let ringBuffer: RingBuffer

  private var audioUnit: AudioUnit?
  private var inputBufferList: UnsafeMutableAudioBufferListPointer?
  private var allocatedFrames: UInt32 = 0
  private var isRunning = false

  init(deviceUID: String, deviceID: AudioDeviceID, channels: Int, sampleRate: Double, bufferFrames: UInt32) {
    self.deviceUID = deviceUID
    self.deviceID = deviceID
    self.channels = channels
    self.sampleRate = sampleRate
    self.bufferFrames = bufferFrames
    let capacity = max(Int(bufferFrames) * 8, 1024)
    self.ringBuffer = RingBuffer(channels: channels, capacityFrames: capacity)
  }

  func start() -> Bool {
    if isRunning {
      return true
    }
    guard channels > 0 else {
      return false
    }
    allocateBuffers(frames: bufferFrames)
    guard let unit = createAudioUnit() else {
      return false
    }
    audioUnit = unit
    isRunning = true
    return true
  }

  func stop() {
    if let unit = audioUnit {
      AudioOutputUnitStop(unit)
      AudioUnitUninitialize(unit)
      AudioComponentInstanceDispose(unit)
    }
    audioUnit = nil
    isRunning = false
    releaseBuffers()
  }

  func registerReader(_ readerId: String) {
    ringBuffer.registerReader(readerId)
  }

  func pruneReaders(keeping readerIds: Set<String>) {
    ringBuffer.pruneReaders(keeping: readerIds)
  }

  private func allocateBuffers(frames: UInt32) {
    if allocatedFrames >= frames, inputBufferList != nil {
      return
    }
    releaseBuffers()
    let bufferList = AudioBufferList.allocate(maximumBuffers: channels)
    for index in 0..<channels {
      bufferList[index].mNumberChannels = 1
      bufferList[index].mDataByteSize = frames * UInt32(MemoryLayout<Float>.size)
      bufferList[index].mData = UnsafeMutableRawPointer.allocate(
        byteCount: Int(bufferList[index].mDataByteSize),
        alignment: MemoryLayout<Float>.alignment
      )
    }
    inputBufferList = bufferList
    allocatedFrames = frames
  }

  private func releaseBuffers() {
    guard let bufferList = inputBufferList else {
      return
    }
    for index in 0..<bufferList.count {
      bufferList[index].mData?.deallocate()
      bufferList[index].mData = nil
    }
    bufferList.unsafeMutablePointer.deallocate()
    inputBufferList = nil
    allocatedFrames = 0
  }

  private func createAudioUnit() -> AudioUnit? {
    var desc = AudioComponentDescription(
      componentType: kAudioUnitType_Output,
      componentSubType: kAudioUnitSubType_HALOutput,
      componentManufacturer: kAudioUnitManufacturer_Apple,
      componentFlags: 0,
      componentFlagsMask: 0
    )
    guard let comp = AudioComponentFindNext(nil, &desc) else {
      return nil
    }
    var unit: AudioUnit?
    guard AudioComponentInstanceNew(comp, &unit) == noErr, let audioUnit = unit else {
      return nil
    }

    var enableIO: UInt32 = 1
    var disableIO: UInt32 = 0
    AudioUnitSetProperty(
      audioUnit,
      kAudioOutputUnitProperty_EnableIO,
      kAudioUnitScope_Input,
      1,
      &enableIO,
      UInt32(MemoryLayout<UInt32>.size)
    )
    AudioUnitSetProperty(
      audioUnit,
      kAudioOutputUnitProperty_EnableIO,
      kAudioUnitScope_Output,
      0,
      &disableIO,
      UInt32(MemoryLayout<UInt32>.size)
    )

    var device = deviceID
    AudioUnitSetProperty(
      audioUnit,
      kAudioOutputUnitProperty_CurrentDevice,
      kAudioUnitScope_Global,
      0,
      &device,
      UInt32(MemoryLayout<AudioDeviceID>.size)
    )

    var format = AudioStreamBasicDescription(
      mSampleRate: sampleRate,
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
      mBytesPerPacket: 4,
      mFramesPerPacket: 1,
      mBytesPerFrame: 4,
      mChannelsPerFrame: UInt32(channels),
      mBitsPerChannel: 32,
      mReserved: 0
    )
    AudioUnitSetProperty(
      audioUnit,
      kAudioUnitProperty_StreamFormat,
      kAudioUnitScope_Output,
      1,
      &format,
      UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    )

    var callback = AURenderCallbackStruct(
      inputProc: InputTap.inputCallback,
      inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
    )
    AudioUnitSetProperty(
      audioUnit,
      kAudioOutputUnitProperty_SetInputCallback,
      kAudioUnitScope_Global,
      0,
      &callback,
      UInt32(MemoryLayout<AURenderCallbackStruct>.size)
    )

    guard AudioUnitInitialize(audioUnit) == noErr else {
      AudioComponentInstanceDispose(audioUnit)
      return nil
    }
    guard AudioOutputUnitStart(audioUnit) == noErr else {
      AudioUnitUninitialize(audioUnit)
      AudioComponentInstanceDispose(audioUnit)
      return nil
    }
    return audioUnit
  }

  private func handleInput(
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32
  ) -> OSStatus {
    guard let audioUnit = audioUnit else {
      return noErr
    }
    if inNumberFrames > allocatedFrames {
      allocateBuffers(frames: inNumberFrames)
    }
    guard let bufferList = inputBufferList else {
      return noErr
    }
    var flags = ioActionFlags.pointee
    let status = AudioUnitRender(
      audioUnit,
      &flags,
      inTimeStamp,
      1,
      inNumberFrames,
      bufferList.unsafeMutablePointer
    )
    if status != noErr {
      return status
    }
    ringBuffer.write(from: bufferList, frames: Int(inNumberFrames))
    return noErr
  }

  private static let inputCallback: AURenderCallback = {
    inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, _ in
    let tap = Unmanaged<InputTap>.fromOpaque(inRefCon).takeUnretainedValue()
    return tap.handleInput(
      ioActionFlags: ioActionFlags,
      inTimeStamp: inTimeStamp,
      inBusNumber: inBusNumber,
      inNumberFrames: inNumberFrames
    )
  }
}

private final class OutputUnit {
  let outputUID: String
  let deviceID: AudioDeviceID
  let channels: Int
  let sampleRate: Double
  let bufferFrames: UInt32
  weak var engine: AudioRouterEngine?

  private var audioUnit: AudioUnit?
  private var scratch: [Float]
  private var isRunning = false

  init(
    outputUID: String,
    deviceID: AudioDeviceID,
    channels: Int,
    sampleRate: Double,
    bufferFrames: UInt32,
    engine: AudioRouterEngine
  ) {
    self.outputUID = outputUID
    self.deviceID = deviceID
    self.channels = channels
    self.sampleRate = sampleRate
    self.bufferFrames = bufferFrames
    self.engine = engine
    self.scratch = Array(repeating: 0, count: Int(bufferFrames))
  }

  func start() -> Bool {
    if isRunning {
      return true
    }
    guard channels > 0 else {
      return false
    }
    guard let unit = createAudioUnit() else {
      return false
    }
    audioUnit = unit
    isRunning = true
    return true
  }

  func stop() {
    if let unit = audioUnit {
      AudioOutputUnitStop(unit)
      AudioUnitUninitialize(unit)
      AudioComponentInstanceDispose(unit)
    }
    audioUnit = nil
    isRunning = false
  }

  private func createAudioUnit() -> AudioUnit? {
    var desc = AudioComponentDescription(
      componentType: kAudioUnitType_Output,
      componentSubType: kAudioUnitSubType_HALOutput,
      componentManufacturer: kAudioUnitManufacturer_Apple,
      componentFlags: 0,
      componentFlagsMask: 0
    )
    guard let comp = AudioComponentFindNext(nil, &desc) else {
      return nil
    }
    var unit: AudioUnit?
    guard AudioComponentInstanceNew(comp, &unit) == noErr, let audioUnit = unit else {
      return nil
    }

    var enableIO: UInt32 = 1
    var disableIO: UInt32 = 0
    AudioUnitSetProperty(
      audioUnit,
      kAudioOutputUnitProperty_EnableIO,
      kAudioUnitScope_Output,
      0,
      &enableIO,
      UInt32(MemoryLayout<UInt32>.size)
    )
    AudioUnitSetProperty(
      audioUnit,
      kAudioOutputUnitProperty_EnableIO,
      kAudioUnitScope_Input,
      1,
      &disableIO,
      UInt32(MemoryLayout<UInt32>.size)
    )

    var device = deviceID
    AudioUnitSetProperty(
      audioUnit,
      kAudioOutputUnitProperty_CurrentDevice,
      kAudioUnitScope_Global,
      0,
      &device,
      UInt32(MemoryLayout<AudioDeviceID>.size)
    )

    var format = AudioStreamBasicDescription(
      mSampleRate: sampleRate,
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
      mBytesPerPacket: 4,
      mFramesPerPacket: 1,
      mBytesPerFrame: 4,
      mChannelsPerFrame: UInt32(channels),
      mBitsPerChannel: 32,
      mReserved: 0
    )
    AudioUnitSetProperty(
      audioUnit,
      kAudioUnitProperty_StreamFormat,
      kAudioUnitScope_Input,
      0,
      &format,
      UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    )

    var callback = AURenderCallbackStruct(
      inputProc: OutputUnit.renderCallback,
      inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
    )
    AudioUnitSetProperty(
      audioUnit,
      kAudioUnitProperty_SetRenderCallback,
      kAudioUnitScope_Input,
      0,
      &callback,
      UInt32(MemoryLayout<AURenderCallbackStruct>.size)
    )

    guard AudioUnitInitialize(audioUnit) == noErr else {
      AudioComponentInstanceDispose(audioUnit)
      return nil
    }
    guard AudioOutputUnitStart(audioUnit) == noErr else {
      AudioUnitUninitialize(audioUnit)
      AudioComponentInstanceDispose(audioUnit)
      return nil
    }
    return audioUnit
  }

  private func render(
    ioData: UnsafeMutableAudioBufferListPointer,
    frames: Int
  ) -> OSStatus {
    if scratch.count < frames {
      scratch = Array(repeating: 0, count: frames)
    }
    return engine?.renderOutput(
      outputUID: outputUID,
      ioData: ioData,
      frames: frames,
      scratch: &scratch
    ) ?? noErr
  }

  private static let renderCallback: AURenderCallback = {
    inRefCon, _, _, _, inNumberFrames, ioData in
    guard let ioData = ioData else {
      return noErr
    }
    let output = Unmanaged<OutputUnit>.fromOpaque(inRefCon).takeUnretainedValue()
    let bufferList = UnsafeMutableAudioBufferListPointer(ioData)
    return output.render(ioData: bufferList, frames: Int(inNumberFrames))
  }
}

private class AudioRouterEngine {
  private(set) var sessionId: String?
  private(set) var outputDeviceUID: String = ""
  private(set) var sampleRate: Int = 0
  private(set) var bufferFrames: Int = 0

  private var routes: [String: Route] = [:]
  private var routesByOutput: [String: [Route]] = [:]
  private var inputTaps: [String: InputTap] = [:]
  private var outputUnits: [String: OutputUnit] = [:]
  private var underruns: Int = 0
  private var overruns: Int = 0
  private var routeLock = os_unfair_lock_s()
  private var statsLock = os_unfair_lock_s()

  func start(outputUID: String, sampleRate: Int, bufferFrames: Int) -> [String: Any] {
    stop()
    sessionId = UUID().uuidString
    outputDeviceUID = outputUID
    self.sampleRate = sampleRate
    self.bufferFrames = bufferFrames
    underruns = 0
    overruns = 0
    return [
      "sessionId": sessionId ?? "",
      "actualSampleRate": sampleRate,
      "bufferFrames": bufferFrames
    ]
  }

  func stop() {
    for unit in outputUnits.values {
      unit.stop()
    }
    for tap in inputTaps.values {
      tap.stop()
    }
    outputUnits.removeAll()
    inputTaps.removeAll()
    routes.removeAll()
    routesByOutput.removeAll()
    sessionId = nil
    outputDeviceUID = ""
    sampleRate = 0
    bufferFrames = 0
  }

  func stats() -> [String: Any] {
    os_unfair_lock_lock(&statsLock)
    let currentUnderruns = underruns
    let currentOverruns = overruns
    os_unfair_lock_unlock(&statsLock)
    let bufferFill = computeBufferFill()
    let routeCount = withRoutes { routes.count }
    let inputTapCount = withRoutes { inputTaps.count }
    let outputUnitCount = withRoutes { outputUnits.count }
    return [
      "underruns": currentUnderruns,
      "overruns": currentOverruns,
      "routes": routeCount,
      "bufferFill": bufferFill,
      "inputTaps": inputTapCount,
      "outputUnits": outputUnitCount
    ]
  }

  func addRoute(args: [String: Any]) -> FlutterError? {
    guard sessionId != nil else {
      return FlutterError(code: "no_session", message: "Start a session before adding routes", details: nil)
    }

    guard let id = args["id"] as? String,
          let inDeviceUID = args["inDeviceUID"] as? String,
          let outDeviceUID = args["outDeviceUID"] as? String else {
      return FlutterError(code: "invalid_route", message: "Route must include id/inDeviceUID/outDeviceUID", details: nil)
    }

    guard let inputDeviceID = AudioDeviceCatalog.deviceID(forUID: inDeviceUID) else {
      return FlutterError(code: "input_device_not_found", message: "Input device not found", details: inDeviceUID)
    }
    guard let outputDeviceID = AudioDeviceCatalog.deviceID(forUID: outDeviceUID) else {
      return FlutterError(code: "output_device_not_found", message: "Output device not found", details: outDeviceUID)
    }

    let targetSampleRate = sampleRate > 0 ? Double(sampleRate) : 48000
    let targetBufferFrames = bufferFrames > 0 ? UInt32(bufferFrames) : 256
    if Int(targetSampleRate) != 48000 {
      return FlutterError(code: "unsupported_sample_rate", message: "Only 48kHz is supported in MVP", details: nil)
    }

    if !AudioDeviceCatalog.supportsSampleRate(inputDeviceID, sampleRate: targetSampleRate) ||
        !AudioDeviceCatalog.supportsSampleRate(outputDeviceID, sampleRate: targetSampleRate) {
      return FlutterError(code: "sample_rate_not_supported", message: "Device does not support 48kHz", details: nil)
    }
    if !AudioDeviceCatalog.setSampleRate(inputDeviceID, sampleRate: targetSampleRate) ||
        !AudioDeviceCatalog.setSampleRate(outputDeviceID, sampleRate: targetSampleRate) {
      return FlutterError(code: "sample_rate_set_failed", message: "Failed to set sample rate", details: nil)
    }
    if !AudioDeviceCatalog.setBufferFrames(inputDeviceID, bufferFrames: targetBufferFrames) ||
        !AudioDeviceCatalog.setBufferFrames(outputDeviceID, bufferFrames: targetBufferFrames) {
      return FlutterError(code: "buffer_set_failed", message: "Failed to set buffer size", details: nil)
    }

    let inputChannels = AudioDeviceCatalog.inputChannelCount(inputDeviceID)
    let outputChannels = AudioDeviceCatalog.outputChannelCount(outputDeviceID)
    if inputChannels == 0 || outputChannels == 0 {
      return FlutterError(code: "invalid_device_channels", message: "Device has no channels", details: nil)
    }

    let inL = max(0, ((args["inL"] as? NSNumber)?.intValue ?? 1) - 1)
    let inR = max(0, ((args["inR"] as? NSNumber)?.intValue ?? 2) - 1)
    let outL = max(0, ((args["outL"] as? NSNumber)?.intValue ?? 1) - 1)
    let outR = max(0, ((args["outR"] as? NSNumber)?.intValue ?? 2) - 1)
    let gain = (args["gain"] as? NSNumber)?.doubleValue ?? 1.0
    let enabled = (args["enabled"] as? Bool) ?? true

    if inL >= inputChannels || inR >= inputChannels {
      return FlutterError(code: "invalid_input_channel", message: "Input channel out of range", details: nil)
    }
    if outL >= outputChannels || outR >= outputChannels {
      return FlutterError(code: "invalid_output_channel", message: "Output channel out of range", details: nil)
    }

    let inputTap: InputTap
    if let existingTap = inputTaps[inDeviceUID] {
      inputTap = existingTap
    } else {
      let newTap = InputTap(
        deviceUID: inDeviceUID,
        deviceID: inputDeviceID,
        channels: inputChannels,
        sampleRate: targetSampleRate,
        bufferFrames: targetBufferFrames
      )
      guard newTap.start() else {
        return FlutterError(code: "input_start_failed", message: "Failed to start input tap", details: inDeviceUID)
      }
      inputTaps[inDeviceUID] = newTap
      inputTap = newTap
      // Give the input tap time to fill the buffer before starting output
      Thread.sleep(forTimeInterval: 0.05)
    }

    let outputUnit: OutputUnit
    if let existingUnit = outputUnits[outDeviceUID] {
      outputUnit = existingUnit
    } else {
      // Register reader before starting output to ensure proper buffer position
      inputTap.registerReader(outDeviceUID)
      
      let newUnit = OutputUnit(
        outputUID: outDeviceUID,
        deviceID: outputDeviceID,
        channels: outputChannels,
        sampleRate: targetSampleRate,
        bufferFrames: targetBufferFrames,
        engine: self
      )
      guard newUnit.start() else {
        return FlutterError(code: "output_start_failed", message: "Failed to start output unit", details: outDeviceUID)
      }
      outputUnits[outDeviceUID] = newUnit
      outputUnit = newUnit
    }

    // Register reader if not already done (for existing output units)
    inputTap.registerReader(outputUnit.outputUID)

    let route = Route(
      id: id,
      inDeviceUID: inDeviceUID,
      outDeviceUID: outDeviceUID,
      inL: inL,
      inR: inR,
      outL: outL,
      outR: outR,
      gain: gain,
      enabled: enabled
    )

    withRoutes {
      routes[id] = route
      rebuildRouteIndexes()
    }
    cleanupResources()
    return nil
  }

  func removeRoute(id: String) {
    withRoutes {
      routes.removeValue(forKey: id)
      rebuildRouteIndexes()
    }
    cleanupResources()
  }

  func setRouteEnabled(id: String, enabled: Bool) {
    withRoutes {
      guard var route = routes[id] else { return }
      route.enabled = enabled
      routes[id] = route
      rebuildRouteIndexes()
    }
  }

  func setRouteGain(id: String, gain: Double) {
    withRoutes {
      guard var route = routes[id] else { return }
      route.gain = gain
      routes[id] = route
      rebuildRouteIndexes()
    }
  }

  func handleDeviceDisconnected(uid: String) {
    // Find and disable routes that use the disconnected device
    var affectedRouteIds: [String] = []
    
    withRoutes {
      for (routeId, route) in routes {
        if route.inDeviceUID == uid || route.outDeviceUID == uid {
          affectedRouteIds.append(routeId)
        }
      }
      
      // Mark affected routes as disabled
      for routeId in affectedRouteIds {
        if var route = routes[routeId] {
          route.enabled = false
          routes[routeId] = route
        }
      }
      rebuildRouteIndexes()
    }
    
    // Stop input taps and output units for disconnected device
    if let tap = inputTaps[uid] {
      tap.stop()
      inputTaps.removeValue(forKey: uid)
    }
    
    if let unit = outputUnits[uid] {
      unit.stop()
      outputUnits.removeValue(forKey: uid)
    }
  }

  func getDisabledRoutesByDevice() -> [String: [String]] {
    // Returns a map of device UID to route IDs that are disabled due to that device
    var result: [String: [String]] = [:]
    
    withRoutes {
      for (routeId, route) in routes where !route.enabled {
        // Check if input device exists
        if AudioDeviceCatalog.deviceID(forUID: route.inDeviceUID) == nil {
          result[route.inDeviceUID, default: []].append(routeId)
        }
        // Check if output device exists
        if AudioDeviceCatalog.deviceID(forUID: route.outDeviceUID) == nil {
          result[route.outDeviceUID, default: []].append(routeId)
        }
      }
    }
    
    return result
  }

  func renderOutput(
    outputUID: String,
    ioData: UnsafeMutableAudioBufferListPointer,
    frames: Int,
    scratch: inout [Float]
  ) -> OSStatus {
    if frames <= 0 {
      return noErr
    }
    for buffer in ioData {
      if let data = buffer.mData {
        memset(data, 0, Int(buffer.mDataByteSize))
      }
    }

    let routesForOutput = withRoutes { routesByOutput[outputUID] ?? [] }
    if routesForOutput.isEmpty {
      return noErr
    }

    var readWindows: [String: ReadWindow] = [:]
    for route in routesForOutput where route.enabled {
      guard let inputTap = withRoutes({ inputTaps[route.inDeviceUID] }) else {
        continue
      }
      let window: ReadWindow
      if let cached = readWindows[route.inDeviceUID] {
        window = cached
      } else {
        let newWindow = inputTap.ringBuffer.beginRead(readerId: outputUID, frames: frames)
        readWindows[route.inDeviceUID] = newWindow
        recordStats(underrun: newWindow.underrun, overrun: newWindow.overrun)
        window = newWindow
      }

      if window.frames == 0 {
        continue
      }

      mix(
        route: route,
        window: window,
        ioData: ioData,
        inputTap: inputTap,
        outputUID: outputUID,
        scratch: &scratch
      )
    }

    for (inputUID, window) in readWindows {
      withRoutes({ inputTaps[inputUID] })?.ringBuffer.endRead(readerId: outputUID, frames: window.frames)
    }

    return noErr
  }

  private func mix(
    route: Route,
    window: ReadWindow,
    ioData: UnsafeMutableAudioBufferListPointer,
    inputTap: InputTap,
    outputUID: String,
    scratch: inout [Float]
  ) {
    let frames = window.frames
    if frames <= 0 {
      return
    }
    if scratch.count < frames {
      scratch = Array(repeating: 0, count: frames)
    }

    if route.outL < ioData.count && route.inL < inputTap.channels {
      scratch.withUnsafeMutableBufferPointer { scratchPtr in
        guard let scratchBase = scratchPtr.baseAddress else { return }
        memset(scratchBase, 0, frames * MemoryLayout<Float>.size)
        inputTap.ringBuffer.readChannel(
          readerId: outputUID,
          startFrame: window.startFrame,
          frames: frames,
          channel: route.inL,
          into: scratchBase
        )
        guard let outData = ioData[route.outL].mData else { return }
        let outBuffer = outData.assumingMemoryBound(to: Float.self)
        for index in 0..<frames {
          outBuffer[index] += scratchBase[index] * Float(route.gain)
        }
      }
    }

    if route.outR < ioData.count && route.inR < inputTap.channels {
      scratch.withUnsafeMutableBufferPointer { scratchPtr in
        guard let scratchBase = scratchPtr.baseAddress else { return }
        memset(scratchBase, 0, frames * MemoryLayout<Float>.size)
        inputTap.ringBuffer.readChannel(
          readerId: outputUID,
          startFrame: window.startFrame,
          frames: frames,
          channel: route.inR,
          into: scratchBase
        )
        guard let outData = ioData[route.outR].mData else { return }
        let outBuffer = outData.assumingMemoryBound(to: Float.self)
        for index in 0..<frames {
          outBuffer[index] += scratchBase[index] * Float(route.gain)
        }
      }
    }
  }

  private func cleanupResources() {
    let activeInputs = Set(withRoutes { routes.values.map { $0.inDeviceUID } })
    let activeOutputs = Set(withRoutes { routes.values.map { $0.outDeviceUID } })

    let tapsToStop: [InputTap] = withRoutes {
      let removed = inputTaps.filter { !activeInputs.contains($0.key) }
      for (uid, _) in removed {
        inputTaps.removeValue(forKey: uid)
      }
      return removed.map { $0.value }
    }
    let unitsToStop: [OutputUnit] = withRoutes {
      let removed = outputUnits.filter { !activeOutputs.contains($0.key) }
      for (uid, _) in removed {
        outputUnits.removeValue(forKey: uid)
      }
      return removed.map { $0.value }
    }

    for tap in tapsToStop {
      tap.stop()
    }
    for unit in unitsToStop {
      unit.stop()
    }

    withRoutes {
      for tap in inputTaps.values {
        tap.pruneReaders(keeping: activeOutputs)
      }
    }
  }

  private func computeBufferFill() -> Double {
    guard let outputUID = withRoutes({ outputUnits.keys.first }) else {
      return 0.0
    }
    let fills = withRoutes({ inputTaps.values.map { $0.ringBuffer.fillRatio(readerId: outputUID) } })
    guard !fills.isEmpty else {
      return 0.0
    }
    let total = fills.reduce(0.0, +)
    return total / Double(fills.count)
  }

  private func rebuildRouteIndexes() {
    routesByOutput = Dictionary(grouping: routes.values, by: { $0.outDeviceUID })
  }

  private func recordStats(underrun: Bool, overrun: Bool) {
    if !underrun && !overrun {
      return
    }
    os_unfair_lock_lock(&statsLock)
    if underrun {
      underruns += 1
    }
    if overrun {
      overruns += 1
    }
    os_unfair_lock_unlock(&statsLock)
  }

  private func withRoutes<T>(_ work: () -> T) -> T {
    os_unfair_lock_lock(&routeLock)
    let result = work()
    os_unfair_lock_unlock(&routeLock)
    return result
  }
}
