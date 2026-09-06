function helperPathFromUrl(url) {
  var text = String(url || "")
  if (text.indexOf("file://") === 0) {
    var path = text.substring(7)
    if (path.charAt(0) !== "/") path = "/" + path
    try { return decodeURIComponent(path) } catch (e) { return path }
  }
  return text
}

function deviceList(devices) {
  if (!devices) return []
  if (devices.values && devices.values !== devices) return deviceList(devices.values)
  var out = []
  var n = devices.length
  if (typeof n === "number") {
    for (var i = 0; i < n; i++) {
      if (devices[i]) out.push(devices[i])
    }
    return out
  }
  if (Array.isArray(devices)) return devices
  return []
}

function modelText(device) {
  return device && device.model ? String(device.model) : ""
}

function isPeripheral(device) {
  if (!device || device.isPresent === false) return false
  if (device.powerSupply || device.isLaptopBattery) return false
  var typeName = ""
  if (device.type !== undefined && device.type !== null) typeName = String(device.type)
  var model = modelText(device).toLowerCase()
  var path = device.nativePath ? String(device.nativePath).toLowerCase() : ""
  if (typeName.indexOf("Touchpad") >= 0) return true
  if (model.indexOf("trackpad") >= 0 || model.indexOf("touchpad") >= 0) return true
  if (path.indexOf("magic-trackpad") >= 0 || path.indexOf("trackpad") >= 0) return true
  if (typeName.indexOf("Mouse") >= 0 || typeName.indexOf("Keyboard") >= 0) return true
  return false
}

function rank(device) {
  var typeName = device && device.type !== undefined ? String(device.type) : ""
  var model = modelText(device).toLowerCase()
  if (typeName.indexOf("Touchpad") >= 0 || model.indexOf("trackpad") >= 0 || model.indexOf("touchpad") >= 0) return 0
  if (typeName.indexOf("Mouse") >= 0) return 1
  if (typeName.indexOf("Keyboard") >= 0) return 2
  return 3
}

function peripherals(devices) {
  var list = deviceList(devices)
  var out = []
  for (var i = 0; i < list.length; i++) {
    if (isPeripheral(list[i])) out.push(list[i])
  }
  out.sort(function(a, b) { return rank(a) - rank(b) })
  return out
}

function preferredDevice(devices) {
  var list = peripherals(devices)
  return list.length ? list[0] : null
}

function percentFromNumber(p) {
  p = Number(p)
  if (!isFinite(p)) return -1
  if (p > 1) return Math.round(Math.max(0, Math.min(100, p)))
  return Math.round(Math.max(0, Math.min(1, p)) * 100)
}

function percent(device) {
  if (!device || device.isPresent === false) return -1
  return percentFromNumber(device.percentage)
}

function fraction(device) {
  var n = percent(device)
  return n < 0 ? 0 : n / 100
}

function isCharging(device, states) {
  if (!device) return false
  var s = states || {}
  return device.state === s.Charging || device.state === s.PendingCharge
}

function stateLabel(device, states) {
  if (!device) return "Disconnected"
  if (isCharging(device, states)) return "Charging"
  if (states && device.state === states.FullyCharged) return "Charged"
  return "Discharging"
}

function displayName(device) {
  var model = modelText(device)
  if (!model) return "Trackpad"
  if (model.toLowerCase().indexOf("trackpad") >= 0 || model.toLowerCase().indexOf("touchpad") >= 0) return model
  return model + " Trackpad"
}

function icon() {
  return "󰟸"
}

function defaultFeatures() {
  return { drag3fg: true, swipe4: true, macosAccel: true }
}

function flagValue(parsed, key) {
  if (!parsed || parsed[key] === undefined || parsed[key] === null) return true
  return parsed[key] === true
}

function parseStatus(raw) {
  var fallback = defaultFeatures()
  try {
    var parsed = JSON.parse(String(raw || "{}"))
    return {
      drag3fg: flagValue(parsed, "drag3fg"),
      swipe4: flagValue(parsed, "swipe4"),
      macosAccel: flagValue(parsed, "macosAccel"),
      enabled: parsed.enabled !== false,
      requirePresent: parsed.requirePresent === true
    }
  } catch (e) {
    fallback.enabled = true
    fallback.requirePresent = false
    return fallback
  }
}

function emptyBattery() {
  return { present: false, percentage: -1, status: "Disconnected", model: "", stale: false, source: "none" }
}

function parseBattery(raw) {
  try {
    var parsed = JSON.parse(String(raw || "{}"))
    var pct = parseInt(parsed.percentage, 10)
    if (!isFinite(pct)) pct = -1
    return {
      present: parsed.present === true,
      percentage: pct,
      status: String(parsed.status || "Unknown"),
      model: String(parsed.model || ""),
      stale: parsed.stale === true,
      source: String(parsed.source || "")
    }
  } catch (e) {
    return emptyBattery()
  }
}
