module("luci.controller.imei", package.seeall)

function index()
    entry({"admin", "modem", "imei"}, cbi("imei"), _("IMEI Generator"), 90)
end
