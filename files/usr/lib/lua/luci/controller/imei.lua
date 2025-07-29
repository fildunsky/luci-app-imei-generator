module("luci.controller.imei", package.seeall)

function index()
    entry({"admin", "network", "imei"}, cbi("imei"), _("IMEI Generator"), 90)
end
