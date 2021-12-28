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
local OptionControl = require "Unit.MenuControl.OptionControl"
local MenuHeader = require "Unit.MenuControl.Header"
local Task = require "Unit.MenuControl.Task"

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
  local freeze = self:addObject("freeze", app.Comparator())
  freeze:setOptionValue("Mode", app.COMPARATOR_GATE)
  self:addMonoBranch("freeze", freeze, "In", freeze, "Out")
  connect(freeze, "Out", grainL, "Freeze")

  local speed = self:createControl("speed", app.GainBias())
  local tune = self:createControl("tune", app.ConstantOffset())
  local pitch = self:addObject("pitch", libcore.VoltPerOctave())
  local multiply = self:addObject("multiply", app.Multiply())
  local clipper = self:addObject("clipper", libcore.Clipper())
  clipper:setMaximum(64.0)
  clipper:setMinimum(-64.0)

  local xfade = self:addObject("xfade", app.StereoCrossFade())
  local fader = self:createControl("fader", app.GainBias())
  connect(fader, "Out", xfade, "Fade")

  -- Pitch and Linear FM
  connect(tune, "Out", pitch, "In")
  connect(pitch, "Out", multiply, "Left")
  connect(speed, "Out", multiply, "Right")
  connect(multiply, "Out", clipper, "In")

  local feedbackGainAdapter = self:createAdapterControl("feedbackGainAdapter")

  local tone = self:createControl("tone", app.GainBias())
  local eqHigh = self:createEqHighControl(tone)
  local eqMid = self:createEqMidControl()
  local eqLow = self:createEqLowControl(tone)

  local feedbackMixL = self:addObject("feedbackMixL", app.Sum())
  local feedbackGainL = self:addObject("feedbackGainL", app.ConstantGain())
  feedbackGainL:setClampInDecibels(-35.9)

  local limiterL = self:addObject("limiter", libcore.Limiter())
  limiterL:setOptionValue("Type", libcore.LIMITER_CUBIC)

  local eqL = self:createEq("eqL", eqHigh, eqMid, eqLow)

  tie(feedbackGainL, "Gain", feedbackGainAdapter, "Out")

  connect(self, "In1", xfade, "Left B")
  connect(self, "In1", feedbackMixL, "Left")
  connect(feedbackMixL, "Out", eqL, "In")
  connect(eqL, "Out", grainL, "In")
  connect(grainL, "Out", feedbackGainL, "In")
  connect(grainL, "Out", xfade, "Left A")
  connect(feedbackGainL, "Out", limiterL, "In")
  connect(limiterL, "Out", feedbackMixL, "Right")
  connect(xfade, "Left Out", self, "Out1")

  connect(clipper, "Out", grainL, "Speed")
  connect(trig, "Out", grainL, "Trigger")

  if channelCount == 2 then
    local grainR = self:addObject("grainR", libfdelay.MonoManualGrainDelay(5.0))
    tie(grainR, "Duration", duration, "Out")
    tie(grainR, "Delay", delay, "Out")
    tie(grainR, "Squash", squash, "Out")
    connect(freeze, "Out", grainR, "Freeze")
  
    local feedbackMixR = self:addObject("feedbackMixR", app.Sum())
    local feedbackGainR = self:addObject("feedbackGainR", app.ConstantGain())
    feedbackGainR:setClampInDecibels(-35.9)

    local limiterR = self:addObject("limiter", libcore.Limiter())
    limiterR:setOptionValue("Type", libcore.LIMITER_CUBIC)

    local eqR = self:createEq("eqR", eqHigh, eqMid, eqLow)

    tie(feedbackGainR, "Gain", feedbackGainAdapter, "Out")

    connect(self, "In2", xfade, "Right B")
    connect(self, "In2", feedbackMixR, "Left")
    connect(feedbackMixR, "Out", eqR, "In")
    connect(eqR, "Out", grainR, "In")
    connect(grainR, "Out", feedbackGainR, "In")
    connect(grainR, "Out", xfade, "Right A")
    connect(feedbackGainR, "Out", limiterR, "In")
    connect(limiterR, "Out", feedbackMixR, "Right")
    connect(xfade, "Right Out", self, "Out2")

    connect(clipper, "Out", grainR, "Speed")
    connect(trig, "Out", grainR, "Trigger")
  end
end

local function timeMap(max, n)
  local map = app.LinearDialMap(0, max)
  map:setCoarseRadix(n)
  return map
end

local function feedbackMap()
  local map = app.LinearDialMap(-36, 6)
  map:setZero(-160)
  map:setSteps(6, 1, 0.1, 0.01);
  return map
end

function ManualGrainDelay:setMaxDelay(secs)
  local requested = Utils.round(secs, 1)
  local allocated = Utils.round(self.objects.grainL:setMaxDelay(requested), 1)
  if channelCount == 2 then
    self.objects.grainR:setMaxDelay(requested)
  end
  if allocated > 0 then
    local map = timeMap(allocated, 100)
    self.controls.delay:setBiasMap(map)
  end
end

local menu = {
  -- "setHeader",
  -- "set2s",
  -- "set5s",
  -- "set10s",
  -- "set30s",
  "freezeHeader",
  "freeze"
}

function ManualGrainDelay:onShowMenu(objects, branches)
  local controls = {}

  -- local allocated = Utils.round(self.objects.grainL:getMaxDelay(), 1)
  -- controls.setHeader = MenuHeader {
  --   description = string.format("Current Maximum Delay is %0.1fs.", allocated)
  -- }

  -- controls.set2s = Task {
  --   description = "2s",
  --   task = function()
  --     self:setMaxDelay(2)
  --   end
  -- }

  -- controls.set5s = Task {
  --   description = "5s",
  --   task = function()
  --     self:setMaxDelay(5)
  --   end
  -- }

  -- controls.set10s = Task {
  --   description = "10s",
  --   task = function()
  --     self:setMaxDelay(10)
  --   end
  -- }

  -- controls.set30s = Task {
  --   description = "30s",
  --   task = function()
  --     self:setMaxDelay(30)
  --   end
  -- }

  controls.freezeHeader = MenuHeader {
    description = "Controls"
  }

  controls.freeze = OptionControl {
    description = "Freeze Latch",
    option = objects.freeze:getOption("Mode"),
    choices = {
      "on",
      "off"
    }
  }

  return controls, menu
end

function ManualGrainDelay:onLoadViews(objects, branches)
  local controls = {}
  local views = {collapsed = {}}

  if self.channelCount == 2 then
    views.expanded = {
      "trigger",
      "freeze",
      "pitch",
      "speed",
      "duration",
      "squash",
      "delay",
      "feedback",
      "tone",
      "wet"
    }
  else
    views.expanded = {
      "trigger",
      "freeze",
      "pitch",
      "speed",
      "duration",
      "squash",
      "delay",
      "feedback",
      "tone",
      "wet"
    }
  end

  controls.trigger = Gate {
    button = "trig",
    description = "Trigger",
    branch = branches.trig,
    comparator = objects.trig
  }

  controls.freeze = Gate {
    button = "freeze",
    description = "Freeze",
    branch = branches.freeze,
    comparator = objects.freeze
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

  controls.feedback = GainBias {
    button = "fdbk",
    description = "Feedback",
    branch = branches.feedbackGainAdapter,
    gainbias = objects.feedbackGainAdapter,
    range = objects.feedbackGainAdapter,
    biasMap = feedbackMap(),
    biasUnits = app.unitDecibels
  }
  controls.feedback:setTextBelow(-35.9, "-inf dB")

  controls.tone = GainBias {
    button = "tone",
    description = "Tone",
    branch = branches.tone,
    gainbias = objects.tone,
    range = objects.toneRange,
    biasMap = Encoder.getMap("[-1,1]")
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

-- function ManualGrainDelay:onLoadFinished()
--   self:setMaxDelay(2.0)
-- end

-- function ManualGrainDelay:serialize()
--   local t = Unit.serialize(self)
--   t.maxDelay = self.objects.grainL:getMaxDelay()
--   return t
-- end

-- function ManualGrainDelay:deserialize(t)
--   local time = t.maxDelay
--   if time and time > 0 then self:setMaxDelay(time) end
--   Unit.deserialize(self, t)
-- end

-- function ManualGrainDelay:onRemove()
--   self.objects.grainL:deallocate()
--   if channelCount == 2 then
--     self.objects.grainR:deallocate()
--   end
--   Unit.onRemove(self)
-- end

return ManualGrainDelay
