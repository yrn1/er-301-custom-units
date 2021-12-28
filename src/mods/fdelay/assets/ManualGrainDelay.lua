local app = app
local YBase = require "fdelay.YBase"
local libfdelay = require "fdelay.libfdelay"
local libcore = require "core.libcore"
local Class = require "Base.Class"
local Unit = require "Unit"
local Gate = require "Unit.ViewControl.Gate"
local GainBias = require "Unit.ViewControl.GainBias"
local Pitch = require "Unit.ViewControl.Pitch"
local Utils = require "Utils"
local Encoder = require "Encoder"

local ManualGrainDelay = Class {}
ManualGrainDelay:include(YBase)

function ManualGrainDelay:init(args)
  args.title = "Manual Grain Delay"
  args.mnemonic = "MGD"
  Unit.init(self, args)
  YBase.init(self, args)
end

function ManualGrainDelay:onLoadGraph(channelCount)
  local grainL = self:addObject("grainL", libfdelay.MonoManualGrainDelay(5.0))

  local delay = self:createAdapterControl("delay")
  local duration = self:createAdapterControl("duration")
  duration:hardSet("Bias", 0.1)
  local squash = self:createAdapterControl("squash")
  tie(grainL, "Duration", duration, "Out")
  tie(grainL, "Delay", delay, "Out")
  tie(grainL, "Squash", squash, "Out")

  local trig = self:addObject("trig", app.Comparator())
  self:addMonoBranch("trig", trig, "In", trig, "Out")
  local speed = self:createControl("speed", app.GainBias())
  local tune = self:createControl("tune", app.ConstantOffset())
  local pitch = self:addObject("pitch", libcore.VoltPerOctave())
  local multiply = self:addObject("multiply", app.Multiply())
  local clipper = self:addObject("clipper", libcore.Clipper())
  clipper:setMaximum(64.0)
  clipper:setMinimum(-64.0)

  local xfade = self:addObject("xfade", app.StereoCrossFade())
  local fader = self:createControl("fader", app.GainBias())
  connect(self, "In1", grainL, "In")
  connect(self, "In1", xfade, "Left B")
  connect(xfade, "Left Out", self, "Out1")
  connect(grainL, "Out", xfade, "Left A")
  connect(fader, "Out", xfade, "Fade")

  connect(trig, "Out", grainL, "Trigger")

  -- Pitch and Linear FM
  connect(tune, "Out", pitch, "In")
  connect(pitch, "Out", multiply, "Left")
  connect(speed, "Out", multiply, "Right")
  connect(multiply, "Out", clipper, "In")
  connect(clipper, "Out", grainL, "Speed")

  if channelCount == 2 then
    local grainR = self:addObject("grainR", libfdelay.MonoManualGrainDelay(5.0))
    tie(grainR, "Duration", duration, "Out")
    tie(grainR, "Delay", delay, "Out")
    tie(grainR, "Squash", squash, "Out")
  
    connect(self, "In2", grainR, "In")
    connect(self, "In2", xfade, "Right B")
    connect(xfade, "Right Out", self, "Out2")
    connect(grainR, "Out", xfade, "Right A")

    connect(clipper, "Out", grainR, "Speed")

    connect(trig, "Out", grainR, "Trigger")
  end
end

local function timeMap(max, n)
  local map = app.LinearDialMap(0, max)
  map:setCoarseRadix(n)
  return map
end

function ManualGrainDelay:onLoadViews(objects, branches)
  local controls = {}
  local views = {collapsed = {}}

  if self.channelCount == 2 then
    views.expanded = {
      "trigger",
      "pitch",
      "speed",
      "delay",
      "duration",
      "squash",
      "wet"
    }
  else
    views.expanded = {
      "trigger",
      "pitch",
      "speed",
      "delay",
      "duration",
      "squash",
      "wet"
    }
  end

  controls.trigger = Gate {
    button = "trig",
    description = "Trigger",
    branch = branches.trig,
    comparator = objects.trig
  }

  controls.pitch = Pitch {
    button = "V/oct",
    description = "V/oct",
    branch = branches.tune,
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.speed = GainBias {
    button = "speed",
    branch = branches.speed,
    description = "Speed",
    gainbias = objects.speed,
    range = objects.speedRange,
    biasMap = Encoder.getMap("speed"),
    biasUnits = app.unitNone,
    initialBias = 1.0
  }

  local allocated = Utils.round(self.objects.grainL:getMaxDelay(), 1)

  controls.delay = GainBias {
    button = "delay",
    description = "Delay",
    branch = branches.delay,
    gainbias = objects.delay,
    range = objects.delay,
    biasMap = timeMap(allocated, 100),
    biasUnits = app.unitSecs
  }

  controls.duration = GainBias {
    button = "dur",
    description = "Duration",
    branch = branches.duration,
    gainbias = objects.duration,
    range = objects.duration,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitSecs
  }

  controls.squash = GainBias {
    button = "squash",
    description = "Squash",
    branch = branches.squash,
    gainbias = objects.squash,
    range = objects.squash,
    biasMap = Encoder.getMap("gain36dB"),
    biasUnits = app.unitDecibels,
    initialBias = 1.0
  }

  controls.wet = GainBias {
    button = "wet",
    branch = branches.fader,
    description = "Wet/Dry",
    gainbias = objects.fader,
    range = objects.faderRange,
    biasMap = Encoder.getMap("unit"),
    initialBias = 0.5
  }

  return controls, views
end

return ManualGrainDelay
