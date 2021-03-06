ControllerLobby = ControllerBase:new(nil)

function ControllerLobby:new(o, controller_mgr, controller_data, guid)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    o.ControllerData = controller_data
    o.ControllerMgr = controller_mgr
    o.Guid = guid
    o.ViewMgr = ViewMgr:new(nil)

    return o
end

function ControllerLobby:onCreate()
    self.CasinosContext = CS.Casinos.CasinosContext.Instance
    self.ControllerIM = self.ControllerMgr:GetController("IM")
    self.ControllerDesktop = self.ControllerMgr:GetController("Desk")
    self.ControllerPlayer = self.ControllerMgr:GetController("Player")
    self.ViewMgr:bindEvListener("EvUiClickSearchDesk", self)
    self.ViewMgr:bindEvListener("EvUiClickSearchFriendsDesk", self)
    self.ViewMgr:bindEvListener("EvUiClickPlayInDesk", self)
    self.ViewMgr:bindEvListener("EvUiClickViewInDesk", self)
    self.ViewMgr:bindEvListener("EvUiClickLeaveLobby", self)
    self.ViewMgr:bindEvListener("EvUiRequestGetCurrentFriendPlayDesk", self)
    self.ViewMgr:bindEvListener("EvUiClickCreateDeskTop", self)
    self.ViewMgr:bindEvListener("EvUiClickExitDesk", self)
    self.ViewMgr:bindEvListener("EvUiRequestEnterDesktopGFlower", self)

    local rpc = self.ControllerMgr.RPC
    rpc:RegRpcMethod1(CommonMethodType.SearchDesktopListNotify, function(list_desktopinfo)
        self:OnSearchDesktopListNotify(list_desktopinfo)
    end)
    rpc:RegRpcMethod1(CommonMethodType.SearchDesktopByPlayerGuidNotify, function(desktop_info)
        self:OnSearchDesktopByPlayerGuidNotify(desktop_info)
    end)
end

function ControllerLobby:onDestroy()
    self.ViewMgr:unbindEvListener(self)
end

function ControllerLobby:onUpdate(tm)
end

function ControllerLobby:onHandleEv(ev)
    if (ev.EventName == "EvUiClickSearchDesk")
    then
        self:RequestSearchDesktop(ev.desktop_searchfilter)
    elseif (ev.EventName == "EvUiClickSearchFriendsDesk")
    then
        local list_playerinfo = self.ControllerIM.IMFriendList:getInDesktopFriendList(ev.friend_state)
        local ev = self.ControllerMgr.ViewMgr:getEv("EvEntitySearchPlayingFriend")
        if (ev == nil)
        then
            ev = EvEntitySearchPlayingFriend:new(nil)
        end
        ev.list_playerinfo = list_playerinfo
        self.ControllerMgr.ViewMgr:sendEv(ev)
    elseif (ev.EventName == "EvUiClickPlayInDesk")
    then
        self:RequestEnterDesktop(ev.desk_etguid, true, ev.seat_index, ev.desktop_filter:getData4Pack())
    elseif (ev.EventName == "EvUiClickViewInDesk")
    then
        local self_desktop_etguid = ""
        if (self.ControllerDesktop.DesktopBase ~= nil)
        then
            self_desktop_etguid = self.ControllerDesktop.DesktopBase.Guid
        end
        if ((ev.desk_etguid ~= self_desktop_etguid) and (ev.desk_etguid ~= nil and ev.desk_etguid ~= ""))
        then
            self:RequestEnterDesktop(ev.desk_etguid, false, ev.seat_index, ev.desktop_filter)
        else
            ViewHelper:UiShowInfoSuccess(self.ControllerMgr.ViewMgr.LanMgr:getLanValue("SameTableTips"))
        end
    elseif (ev.EventName == "EvUiClickLeaveLobby")
    then
        self:LeavePlayModel()
    elseif (ev.EventName == "EvUiRequestGetCurrentFriendPlayDesk")
    then
        self.ControllerMgr.RPC:RPC1(CommonMethodType.SearchDesktopByPlayerGuidRequest, ev.player_guid)
    elseif (ev.EventName == "EvUiClickCreateDeskTop")
    then
        self:RequestCreatePrivateDesktop(ev.create_info)
    elseif (ev.EventName == "EvUiClickExitDesk")
    then
        self:RequestLeaveDesktop()
    elseif (ev.EventName == "EvUiRequestEnterDesktopGFlower")
    then
        self:RequestPlayNow(ev.DesktopFilter)
    end
end

function ControllerLobby:RequestCreatePrivateDesktop(create_info)
    local data = create_info:getData4Pack()
    self.ControllerMgr.RPC:RPC1(CommonMethodType.PlayerCreatePrivateDesktopRequest, data)
end

function ControllerLobby:RequestLeaveDesktop()
    ViewHelper:UiBeginWaiting(self.ControllerMgr.ViewMgr.LanMgr:getLanValue("LeavingTable"))
    self.ControllerMgr.RPC:RPC0(CommonMethodType.DesktopPlayerLeaveRequest)
end

function ControllerLobby:OnSearchDesktopListNotify(list_desktopinfo)
    local l_desktopinfo = {}
    for i, v in pairs(list_desktopinfo) do
        local d_info = DesktopInfo:new(nil)
        d_info.FactoryName = v[1]
        d_info.DesktopGuid = v[2]
        d_info.DesktopData = v[3]
        table.insert(l_desktopinfo, d_info)
    end
    local ev = self.ControllerMgr.ViewMgr:getEv("EvEntityGetLobbyDeskList")
    if (ev == nil)
    then
        ev = EvEntityGetLobbyDeskList:new()
    end
    ev.list_desktop = l_desktopinfo
    self.ControllerMgr.ViewMgr:sendEv(ev)
end

function ControllerLobby:OnSearchDesktopByPlayerGuidNotify(desktop_info)
    local d_info = DesktopInfo:new(nil)
    d_info.FactoryName = desktop_info[1]
    d_info.DesktopGuid = desktop_info[2]
    d_info.DesktopData = desktop_info[3]
    local ev = self.ControllerMgr.ViewMgr:getEv("EvEntitySearchDesktopFollowFriend")
    if (ev == nil)
    then
        ev = EvEntitySearchDesktopFollowFriend:new()
    end
    ev.desktop_info = d_info
    self.ControllerMgr.ViewMgr:sendEv(ev)
end

function ControllerLobby:RequestSearchDesktop(search_filter)
    ViewHelper:UiBeginWaiting(self.ControllerMgr.ViewMgr.LanMgr:getLanValue("SearchTable"))
    local p_d = search_filter:getData4Pack()
    self.ControllerMgr.RPC:RPC1(CommonMethodType.SearchDesktopListRequest, p_d)
end

function ControllerLobby:RequestSearchDesktopFollowFriend(desktop_etguid)
    ViewHelper:UiBeginWaiting(self.ControllerMgr.ViewMgr.LanMgr:getLanValue("SearchTable"))
end

function ControllerLobby:RequestSearchPlayingFriend(desktop_type)
    ViewHelper:UiBeginWaiting(self.ControllerMgr.ViewMgr.LanMgr:getLanValue("SearchTable"));
end

function ControllerLobby:RequestEnterDesktop(desktop_etguid, player_or_view, seat_index, desktop_filter)
    ViewHelper:UiBeginWaiting(self.ControllerMgr.ViewMgr.LanMgr:getLanValue("EnterTable"))
    local enter_request = DesktopEnterRequest:new(nil)
    enter_request.desktop_guid = desktop_etguid
    enter_request.seat_index = seat_index
    if (player_or_view == false)
    then
        enter_request.is_ob = true
    else
        enter_request.is_ob = false
    end
    enter_request.desktop_filter = desktop_filter
    local data_4pack = enter_request:getData4Pack()
    self.ControllerMgr.RPC:RPC1(CommonMethodType.DesktopPlayerEnterRequest, data_4pack)
end

function ControllerLobby:RequestPlayNow(desktop_filter)
    ViewHelper:UiBeginWaiting(self.ControllerMgr.ViewMgr.LanMgr:getLanValue("EnterTable"))
    local data = desktop_filter:getData4Pack()
    self.ControllerMgr.RPC:RPC1(CommonMethodType.PlayerPlayNowRequest, data)
end

function ControllerLobby:LeavePlayModel()
    self:HideLobby()
    self.ControllerPlayer:requestGetOnlinePlayerNum()
end

function ControllerLobby:HideLobby()
    ViewHelper:UiEndWaiting()
end

ControllerLobbyFactory = ControllerFactory:new()

function ControllerLobbyFactory:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.ControllerName = "Lobby"
    return o
end

function ControllerLobbyFactory:createController(controller_mgr, controller_data, guid)
    local controller = ControllerLobby:new(nil, controller_mgr, controller_data, guid)
    return controller
end