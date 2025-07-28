module("luci.controller.imei", package.seeall)

function index()
    entry({"admin", "network", "imei"}, cbi("imei"), _("Генератор IMEI"), 90)
end
