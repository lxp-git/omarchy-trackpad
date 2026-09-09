function helperPathFromUrl(url) {
  var text = String(url || "")
  if (text.indexOf("file://") === 0) {
    var path = text.substring(7)
    if (path.charAt(0) !== "/") path = "/" + path
    try { return decodeURIComponent(path) } catch (e) { return path }
  }
  return text
}

function safeHelperPath(path) {
  var text = String(path || "")
  var suffix = "/bin/trackpad-pack"
  if (text.charAt(0) !== "/") return ""
  if (text.length < suffix.length || text.length > 512) return ""
  if (text.indexOf("/../") >= 0 || text.indexOf("/..") === text.length - 3) return ""
  if (text.substring(text.length - suffix.length) !== suffix) return ""
  for (var i = 0; i < text.length; i++) {
    var c = text.charAt(i)
    var ok = (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9")
      || c === "." || c === "_" || c === "/" || c === "-"
    if (!ok) return ""
  }
  return text
}

function helperEnv(qsEnv) {
  var env = { PATH: "/usr/bin:/bin", LC_ALL: "C.UTF-8" }
  var keys = [
    "HOME", "USER", "LOGNAME", "XDG_RUNTIME_DIR", "XDG_CONFIG_HOME",
    "XDG_STATE_HOME", "WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE",
    "DBUS_SESSION_BUS_ADDRESS"
  ]
  for (var i = 0; i < keys.length; i++) {
    var v = qsEnv(keys[i])
    if (v) env[keys[i]] = String(v)
  }
  return env
}

function plain(value, max) {
  var text = String(value == null ? "" : value)
  if (text.length > max) text = text.substring(0, max)
  return text.replace(/[<>&]/g, "").replace(/[\x00-\x1F\x7F-\x9F]/g, "")
}

function resolveHelper(url, home) {
  var fromUrl = safeHelperPath(helperPathFromUrl(url))
  if (fromUrl) return fromUrl
  return safeHelperPath(String(home || "") + "/.config/omarchy/plugins/xuanping.trackpad/bin/trackpad-pack")
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
  if (model.indexOf("magic-trackpad") >= 0 || model.indexOf("trackpad") >= 0 || model.indexOf("touchpad") >= 0) return true
  if (path.indexOf("magic-trackpad") >= 0 || path.indexOf("trackpad") >= 0 || path.indexOf("touchpad") >= 0) return true
  return false
}

function rank(device) {
  var typeName = device && device.type !== undefined ? String(device.type) : ""
  var model = modelText(device).toLowerCase()
  var path = device && device.nativePath ? String(device.nativePath).toLowerCase() : ""
  var blob = model + " " + path
  if (blob.indexOf("magic-trackpad") >= 0 || blob.indexOf("magic trackpad") >= 0) return 0
  if (typeName.indexOf("Touchpad") >= 0 || model.indexOf("trackpad") >= 0 || model.indexOf("touchpad") >= 0) return 1
  if (path.indexOf("trackpad") >= 0 || path.indexOf("touchpad") >= 0) return 1
  return 2
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
  var model = plain(modelText(device), 64)
  return model || "Trackpad"
}

function icon() {
  return "󰟸"
}

function defaultFeatures() {
  return { drag3fg: true, swipe4: true, macosAccel: true, scrollFactor: 0.3 }
}

function flagValue(parsed, key) {
  if (!parsed || parsed[key] === undefined || parsed[key] === null) return true
  return parsed[key] === true
}

function parseScrollFactor(value) {
  var n = Number(value)
  if (!isFinite(n) || n < 0.1 || n > 2) return 0.3
  return Math.round(n * 100) / 100
}

function formatScrollFactor(value) {
  return parseScrollFactor(value).toFixed(2)
}

function parseStatus(raw) {
  var fallback = defaultFeatures()
  try {
    var text = String(raw || "{}")
    if (text.length > 8192) throw new Error("status too large")
    var parsed = JSON.parse(text)
    return {
      drag3fg: flagValue(parsed, "drag3fg"),
      swipe4: flagValue(parsed, "swipe4"),
      macosAccel: flagValue(parsed, "macosAccel"),
      scrollFactor: parseScrollFactor(parsed.scrollFactor),
      enabled: parsed.enabled !== false,
      requirePresent: parsed.requirePresent === true
    }
  } catch (e) {
    fallback.enabled = true
    fallback.requirePresent = false
    return fallback
  }
}

function parseNotify(raw) {
  try {
    var text = String(raw || "")
    if (text.length > 1024) return 100
    var parsed = JSON.parse(text)
    var n = parseInt(parsed.lastNotifiedPercent, 10)
    if (!isFinite(n) || n < 0 || n > 100) return 100
    return n
  } catch (e) {
    return 100
  }
}

function parseHidraw(raw) {
  try {
    var text = String(raw || "")
    if (text.length > 1024) return { ruleInstalled: false, readable: false }
    var parsed = JSON.parse(text)
    return {
      ruleInstalled: parsed.ruleInstalled === true,
      readable: parsed.readable === true
    }
  } catch (e) {
    return { ruleInstalled: false, readable: false }
  }
}

function emptyBattery() {
  return { present: false, percentage: -1, status: "Disconnected", model: "", stale: false, source: "none" }
}

function parseBattery(raw) {
  try {
    var text = String(raw || "")
    if (text.length > 8192) return emptyBattery()
    var start = text.indexOf("{")
    var end = text.lastIndexOf("}")
    if (start < 0 || end <= start) return emptyBattery()
    var parsed = JSON.parse(text.substring(start, end + 1))
    var pct = parseInt(parsed.percentage, 10)
    if (!isFinite(pct) || pct < -1 || pct > 100) pct = -1
    return {
      present: parsed.present === true,
      percentage: pct,
      status: plain(parsed.status || "Unknown", 24) || "Unknown",
      model: plain(parsed.model || "", 96),
      stale: parsed.stale === true,
      source: plain(parsed.source || "", 16)
    }
  } catch (e) {
    return emptyBattery()
  }
}
