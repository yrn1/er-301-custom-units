local app = app
local libcore = require "core.libcore"
local libfdelay = require "fdelay.libfdelay"
local Class = require "Base.Class"
local Unit = require "Unit"
local SamplePool = require "Sample.Pool"
local SamplePoolInterface = require "Sample.Pool.Interface"
local Encoder = require "Encoder"
local Gate = require "Unit.ViewControl.Gate"
local Pitch = require "Unit.ViewControl.Pitch"
local GainBias = require "Unit.ViewControl.GainBias"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local GrainView = require "fdelay.GrainView"
local SampleEditor = require "Sample.Editor"

local ManualGrains = Class {}
ManualGrains:include(Unit)

function ManualGrains:init(args)
  args.title = "Manual Grains"
  args.mnemonic = "MG"
  Unit.init(self, args)
end

function ManualGrains:onLoadGraph(channelCount)
  local head = self:addObject("head", libfdelay.GranularHead(channelCount))

  local start = self:addObject("start", app.ParameterAdapter())
  local duration = self:addObject("duration", app.ParameterAdapter())
  duration:hardSet("Bias", 0.1)
  local gain = self:addObject("gain", app.ParameterAdapter())
  local squash = self:addObject("squash", app.ParameterAdapter())
  tie(head, "Duration", duration, "Out")
  tie(head, "Start", start, "Out")
  tie(head, "Gain", gain, "Out", head, "Gain")
  tie(head, "Squash", squash, "Out")

  local trig = self:addObject("trig", app.Comparator())
  local speed = self:addObject("speed", app.GainBias())
  local tune = self:addObject("tune", app.ConstantOffset())
  local pitch = self:addObject("pitch", libcore.VoltPerOctave())
  local multiply = self:addObject("multiply", app.Multiply())
  local clipper = self:addObject("clipper", libcore.Clipper())
  clipper:setMaximum(64.0)
  clipper:setMinimum(-64.0)

  local tuneRange = self:addObject("tuneRange", app.MinMax())
  local speedRange = self:addObject("speedRange", app.MinMax())

   connect(self, "In1", head, "Left In")

  -- Pitch and Linear FM
  connect(tune, "Out", pitch, "In")
  connect(tune, "Out", tuneRange, "In")
  connect(pitch, "Out", multiply, "Left")
  connect(speed, "Out", multiply, "Right")
  connect(speed, "Out", speedRange, "In")
  connect(multiply, "Out", clipper, "In")
  connect(clipper, "Out", head, "Speed")

  connect(trig, "Out", head, "Trigger")
  connect(head, "Left Out", self, "Out1")

  self:addMonoBranch("speed", speed, "In", speed, "Out")
  self:addMonoBranch("tune", tune, "In", tune, "Out")
  self:addMonoBranch("trig", trig, "In", trig, "Out")
  self:addMonoBranch("start", start, "In", start, "Out")
  self:addMonoBranch("duration", duration, "In", duration, "Out")
  self:addMonoBranch("gain", gain, "In", gain, "Out")
  self:addMonoBranch("squash", squash, "In", squash, "Out")

  if channelCount > 1 then
    connect(self, "In2", head, "Right In")
    local pan = self:addObject("pan", app.ParameterAdapter())
    tie(head, "Pan", pan, "Out")
    connect(head, "Right Out", self, "Out2")
    self:addMonoBranch("pan", pan, "In", pan, "Out")
  end

end

function ManualGrains:serialize()
  local t = Unit.serialize(self)
  return t
end

function ManualGrains:deserialize(t)
  Unit.deserialize(self, t)
end

function ManualGrains:setMaxDelayTime(secs)
  local requested = math.floor(secs + 0.5)
  self.objects.head:setMaxDelay(requested)
end

local stereoViews = {
  expanded = {
    "trigger",
    "pitch",
    "speed",
    "start",
    "duration",
    "pan",
    "gain",
    "squash"
  },
  trigger = {
    "gview",
    "trigger"
  },
  pitch = {
    "gview",
    "pitch"
  },
  speed = {
    "gview",
    "speed"
  },
  start = {
    "gview",
    "start"
  },
  duration = {
    "gview",
    "duration"
  },
  squash = {
    "gview",
    "squash"
  },
  collapsed = {}
}

local monoViews = {
  expanded = {
    "trigger",
    "pitch",
    "speed",
    "start",
    "duration",
    "gain",
    "squash"
  },
  trigger = {
    "gview",
    "trigger"
  },
  pitch = {
    "gview",
    "pitch"
  },
  speed = {
    "gview",
    "speed"
  },
  start = {
    "gview",
    "start"
  },
  duration = {
    "gview",
    "duration"
  },
  squash = {
    "gview",
    "squash"
  },
  collapsed = {}
}

function ManualGrains:onLoadViews(objects, branches)
  local controls = {}

  controls.pitch = Pitch {
    button = "V/oct",
    description = "V/oct",
    branch = branches.tune,
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.speed = GainBias {
    button = "speed",
    description = "Speed",
    branch = branches.speed,
    gainbias = objects.speed,
    range = objects.speedRange,
    biasMap = Encoder.getMap("speed"),
    initialBias = 1.0
  }

  controls.trigger = Gate {
    button = "trig",
    description = "Trigger",
    branch = branches.trig,
    comparator = objects.trig
  }

  controls.start = GainBias {
    button = "start",
    description = "Start",
    branch = branches.start,
    gainbias = objects.start,
    range = objects.start,
    biasMap = Encoder.getMap("unit")
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

  controls.gain = GainBias {
    button = "gain",
    description = "Gain",
    branch = branches.gain,
    gainbias = objects.gain,
    range = objects.gain,
    initialBias = 1.0
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

  controls.gview = GrainView {
    head = objects.head
  }

  if objects.pan then
    controls.pan = GainBias {
      button = "pan",
      branch = branches.pan,
      description = "Pan",
      gainbias = objects.pan,
      range = objects.pan,
      biasMap = Encoder.getMap("default"),
      biasUnits = app.unitNone
    }

    return controls, stereoViews
  else
    return controls, monoViews
  end
end

function ManualGrains:onRemove()
  Unit.onRemove(self)
end

return ManualGrains
