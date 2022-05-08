local app = app
local libcore = require "core.libcore"
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"

local FixedHPFx4 = Class {}
FixedHPFx4:include(Unit)

function FixedHPFx4:init(args)
  args.title = "Fixed HPFx4"
  args.mnemonic = "HF4"
  Unit.init(self, args)
end

function FixedHPFx4:onLoadGraph(channelCount)
  local filter1 = self:addObject("filter1", libcore.StereoFixedHPF())
  local filter2 = self:addObject("filter2", libcore.StereoFixedHPF())
  local filter3 = self:addObject("filter3", libcore.StereoFixedHPF())
  local filter4 = self:addObject("filter4", libcore.StereoFixedHPF())
  tie(filter2, "Cutoff", filter1, "Cutoff")
  tie(filter3, "Cutoff", filter1, "Cutoff")
  tie(filter4, "Cutoff", filter1, "Cutoff")

  connect(self, "In1", filter1, "Left In")
  connect(filter1, "Left Out", filter2, "Left In")
  connect(filter2, "Left Out", filter3, "Left In")
  connect(filter3, "Left Out", filter4, "Left In")
  connect(filter4, "Left Out", self, "Out1")

  if channelCount == 2 then
    connect(self, "In2", filter1, "Right In")
    connect(filter1, "Right Out", filter2, "Right In")
    connect(filter2, "Right Out", filter3, "Right In")
    connect(filter3, "Right Out", filter4, "Right In")
    connect(filter4, "Right Out", self, "Out2")
  end
end

local views = {
  expanded = {
    "freq"
  },
  collapsed = {}
}

function FixedHPFx4:onLoadViews(objects, branches)
  local controls = {}

  controls.freq = Fader {
    button = "freq",
    description = "Cutoff Freq",
    param = objects.filter1:getParameter("Cutoff"),
    map = Encoder.getMap("filterFreq"),
    units = app.unitHertz,
    scaling = app.octaveScaling
  }

  return controls, views
end

return FixedHPFx4
