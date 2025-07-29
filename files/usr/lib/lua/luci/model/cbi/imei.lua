local m = Map("imei", "IMEI Generator")
local nixio = require("nixio")

local devices = {
    ["HONOR Magic7 Pro"]         = "86596507",
    ["iPhone 15 Pro Max"]        = "35630348",
    ["iPhone 16 Pro"]            = "35887662",
    ["OPPO Reno12 Pro"]         = "86945807",
    ["SAMSUNG Galaxy S25+"]      = "35020450",
    ["SAMSUNG Galaxy S25 Ultra"] = "35069390"
}

local d = m:section(NamedSection, "general", "imei", "")

local device = d:option(ListValue, "device", "Device")
for name, _ in pairs(devices) do device:value(name) end
device.default = "iPhone 15 Pro Max"

local port_field = d:option(Value, "port", "Modem port")
port_field.default = "/dev/ttyUSB2"
port_field.datatype = "device"

local generate = d:option(Button, "_generate")
generate.title = ""
generate.inputtitle = "Generate IMEI"
generate.inputstyle = "apply"

local imei_value = d:option(DummyValue, "_imei", "Result IMEI")
imei_value.rawhtml = true

local imei_nv = d:option(DummyValue, "_nv550", "AT IMEI format")
imei_nv.rawhtml = true

local imei_at = d:option(DummyValue, "_atcommand", "AT command")
imei_at.rawhtml = true

local log_output = d:option(DummyValue, "_log", "Execution log")
log_output.rawhtml = true

-- IMEI генератор
local function luhn(imei14)
    local sum = 0
    for i = 1, 14 do
        local digit = tonumber(imei14:sub(i, i))
        if i % 2 == 0 then
            digit = digit * 2
            if digit > 9 then digit = digit - 9 end
        end
        sum = sum + digit
    end
    return tostring((10 - (sum % 10)) % 10)
end

local function convert_imei_to_nv550_format(imei)
    local hex = "80A" .. imei
    local result = {}
    for i = 1, #hex, 2 do
        local a = hex:sub(i, i)
        local b = hex:sub(i + 1, i + 1)
        if #b == 1 then b = b else b = "F" end
        table.insert(result, b .. a)
    end
    return table.concat(result, " "):upper()
end

-- Генерация IMEI
function generate.write(self, section)
    local selected = device:formvalue(section) or device.default
    local tac = devices[selected]
    if not tac then
        luci.http.write("<b>Error:</b> select device!<br>")
        return
    end

    math.randomseed(os.time() + nixio.getpid())

    local snr = string.format("%06d", math.random(0, 999999))
    local imei14 = tac .. snr
    local check = luhn(imei14)
    local full = imei14 .. check

    luci.sys.exec("echo '" .. full .. "' > /tmp/generated_imei")
    luci.sys.exec("echo '" .. selected .. "' > /tmp/generated_device")
    luci.sys.exec("logger -t imei 'IMEI Generated: " .. full .. " (" .. selected .. ")'")
end

-- Отображение IMEI
function imei_value.cfgvalue()
    return luci.sys.exec("cat /tmp/generated_imei 2>/dev/null"):gsub("%s+", "") or "-"
end

-- Отображение AT-формата
function imei_nv.cfgvalue()
    local imei = luci.sys.exec("cat /tmp/generated_imei 2>/dev/null"):gsub("%s+", "")
    if #imei == 15 then
        return convert_imei_to_nv550_format(imei)
    else
        return "-"
    end
end

-- Отображение AT-команды
function imei_at.cfgvalue()
    local imei = luci.sys.exec("cat /tmp/generated_imei 2>/dev/null"):gsub("%s+", "")
    if #imei == 15 then
        local converted = convert_imei_to_nv550_format(imei):gsub(" ", ",")
        return [[<code>AT^NV=550,9,"]] .. converted .. [["</code>]]
    else
        return "-"
    end
end

-- Отображение лога
function log_output.cfgvalue()
    local log = luci.sys.exec("cat /tmp/imei_log.txt 2>/dev/null")
    if log == "" then
        return "<i>No log yet</i>"
    else
        return "<pre>" .. luci.util.pcdata(log) .. "</pre>"
    end
end

-- Кнопка записи IMEI
local apply = d:option(Button, "_apply")
apply.title = ""
apply.inputtitle = "Write IMEI"
apply.inputstyle = "apply"

function apply.write(self, section)
    local port = port_field:formvalue(section) or "/dev/ttyUSB2"
    local imei = luci.sys.exec("cat /tmp/generated_imei 2>/dev/null"):gsub("%s+", "")
    if imei == "" or #imei ~= 15 then
        luci.http.write("<b>Error:</b> No valid IMEI generated.<br>")
        return
    end

    local hexstr = convert_imei_to_nv550_format(imei):gsub(" ", ",")

    local log_lines = {}
    table.insert(log_lines, "Using port: " .. port)
    table.insert(log_lines, "IMEI: " .. imei)
    table.insert(log_lines, 'Sending: AT^NV=550,"0"')
    table.insert(log_lines, 'Sending: AT^NV=550,9,"' .. hexstr .. '"')
    table.insert(log_lines, "Sending: AT+CFUN=1,1")

    luci.sys.exec("echo '' > /tmp/imei_log.txt")
    for _, line in ipairs(log_lines) do
        luci.sys.exec("echo '" .. line .. "' >> /tmp/imei_log.txt")
    end

    luci.sys.exec("echo -e 'AT^NV=550,\"0\"\r' | atinout - " .. port .. " - >> /tmp/imei_log.txt 2>&1")
    luci.sys.exec("echo -e 'AT^NV=550,9,\"" .. hexstr .. "\"\r' | atinout - " .. port .. " - >> /tmp/imei_log.txt 2>&1")
    luci.sys.exec("echo -e 'AT+CFUN=1,1\r' | atinout - " .. port .. " - >> /tmp/imei_log.txt 2>&1")

    luci.sys.exec("logger -t imei 'Written IMEI " .. imei .. " to port " .. port .. "'")
    luci.sys.exec("touch /etc/imei_user_set")
end

return m

