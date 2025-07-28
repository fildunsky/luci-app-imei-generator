local m = Map("imei", "IMEI Generator")
local nixio = require("nixio")

local devices = {
    ["iPhone 15 Pro Max"]        = "35630348",
    ["iPhone 16 Pro"]            = "35887662",
    ["SAMSUNG Galaxy S25+"]      = "35020450",
    ["SAMSUNG Galaxy S25 Ultra"] = "35069390",
    ["HONOR Magic7 Pro"]         = "86596507",
    ["OPPO Reno 12 Pro"]         = "86945807"
}

local d = m:section(NamedSection, "general", "imei", "")
local device = d:option(ListValue, "device", "Device:")
for name, _ in pairs(devices) do device:value(name) end
device.default = "iPhone 15 Pro Max"

local generate = d:option(Button, "_generate", "Generate IMEI")
generate.inputstyle = "apply"

local imei_value = d:option(DummyValue, "_imei", "Result IMEI")
imei_value.rawhtml = true

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


function imei_value.cfgvalue()
    return luci.sys.exec("cat /tmp/generated_imei 2>/dev/null"):gsub("%s+", "") or "-"
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

local imei_nv = d:option(DummyValue, "_nv550", "AT IMEI")
imei_nv.rawhtml = true

function imei_nv.cfgvalue()
    local imei = luci.sys.exec("cat /tmp/generated_imei 2>/dev/null"):gsub("%s+", "")
    if #imei == 15 then
        return convert_imei_to_nv550_format(imei)
    else
        return "-"
    end
end

local function wait_for_port(port, timeout)
    local t = 0
    while not nixio.fs.access(port) and t < timeout do
        luci.sys.exec("sleep 1")
        t = t + 1
    end
end

local apply = d:option(Button, "_apply", "Write IMEI")
apply.inputstyle = "apply"

function apply.write(self, section)
    local imsi = luci.sys.exec("microcom -t 3000 -s 115200 /dev/ttyUSB2 <<< 'AT+CIMI'" .. " | grep -E '^[0-9]{15}' | head -n1"):gsub("%s+", "")
    if imsi ~= "" and #imsi == 15 then
        luci.http.write("<b>Warning:</b> SIM card inserted. Forcing to newly generated IMEI.<br>")
    end
    local imei = luci.sys.exec("cat /tmp/generated_imei 2>/dev/null"):gsub("%s+", "")
    if imei ~= "" and #imei == 15 then
        local port = "/dev/ttyUSB2"
        local hexstr = convert_imei_to_nv550_format(imei)

        luci.sys.exec("logger -t imei 'Writing IMEI: " .. imei .. "'")
        luci.sys.exec("echo -e 'AT^NV=550,\"0\"\r' > " .. port)
        luci.sys.exec("sleep 1")
        luci.sys.exec("echo -e 'AT^NV=550,9,\"" .. hexstr .. "\"\r' > " .. port)
        luci.sys.exec("touch /etc/imei_user_set")
    end
end

return m
