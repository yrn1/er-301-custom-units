local libcore = require "core.libcore"
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"
local GainBias = require "Unit.ViewControl.GainBias"
local Pitch = require "Unit.ViewControl.Pitch"

local EQSweeps = Class {}
EQSweeps:include(Unit)

function EQSweeps:init(args)
  args.title = "EQ Sweeps"
  args.mnemonic = "EQS"
  args.version = 1
  Unit.init(self, args)
end

function EQSweeps:onLoadGraph(channelCount)
  local resonance = self:addObject("resonance", app.GainBias())
  local resonanceRange = self:addObject("resonanceRange", app.MinMax())
  connect(resonance, "Out", resonanceRange, "In")
  self:addMonoBranch("resonance", resonance, "In", resonance, "Out")

  local width = self:addObject("width", app.GainBias())
  local widthRange = self:addObject("widthRange", app.MinMax())
  connect(width, "Out", widthRange, "In")
  self:addMonoBranch("width", width, "In", width, "Out")

  local speed = self:addObject("speed", app.GainBias())
  local speedRange = self:addObject("speedRange", app.MinMax())
  connect(speed, "Out", speedRange, "In")
  self:addMonoBranch("speed", speed, "In", speed, "Out")

  local amp = self:addObject("amp", app.GainBias())
  local ampRange = self:addObject("ampRange", app.MinMax())
  connect(amp, "Out", ampRange, "In")
  self:addMonoBranch("amp", amp, "In", amp, "Out")

  local center = self:addObject("center", app.GainBias())
  local centerRange = self:addObject("centerRange", app.MinMax())
  connect(center, "Out", centerRange, "In")
  self:addMonoBranch("center", center, "In", center, "Out")

  local zero = self:addObject("zero", app.Constant())
  zero:hardSet("Value", 0.0)

  local lfoLL = self:lfo("lfoLL", zero, speed, 0.89)
  local lpfLL = self:lpf("lpfLL", center, resonance, lfoLL, amp, width)
  local hpfLL = self:hpf("hpfLL", center, resonance, lfoLL, amp, width)

  local lfoRR = self:lfo("lfoRR", zero, speed, 0.97)
  local lpfRR = self:lpf("lpfRR", center, resonance, lfoRR, amp, width)
  local hpfRR = self:hpf("hpfRR", center, resonance, lfoRR, amp, width)

  connect(self, "In1", lpfLL, "Left In")
  connect(lpfLL, "Left Out", hpfLL, "Left In")
  connect(hpfLL, "Left Out", self, "Out1")

  connect(self, "In2", lpfRR, "Right In")
  connect(lpfRR, "Right Out", hpfRR, "Right In")
  connect(hpfRR, "Right Out", self, "Out2")
end

function EQSweeps:lpf(name, fundamental, resonance, lfo, amp, width)
  local halfWidth = self:addObject(name .. "HalfWidth", app.ConstantGain())
  halfWidth:hardSet("Value", -0.5)
  connect(width, "Out", halfWidth, "In")

  local gain = self:addObject(name .. "Gain", app.Gain())
  connect(lfo, "Out", gain, "In")
  connect(amp, "Out", gain, "Gain")
  
  local sum = self:addObject(name .. "Sum", app.Sum())
  connect(gain, "Out", sum, "Left")
  connect(halfWidth, "Out", sum, "Right")

  local filter = self:addObject(name, libcore.StereoLadderFilter())
  connect(fundamental, "Out", filter, "Fundamental")
  connect(resonance, "Out", filter, "Resonance")
  connect(sum, "Out", filter, "V/Oct")
  return filter
end

function EQSweeps:hpf(name, fundamental, resonance, lfo, amp, width)
  local halfWidth = self:addObject(name .. "HalfWidth", app.ConstantGain())
  halfWidth:hardSet("Value", -0.5)
  connect(width, "Out", halfWidth, "In")

  local gain = self:addObject(name .. "Gain", app.Gain())
  connect(lfo, "Out", gain, "In")
  connect(amp, "Out", gain, "Gain")
  
  local sum = self:addObject(name .. "Sum", app.Sum())
  connect(gain, "Out", sum, "Left")
  connect(halfWidth, "Out", sum, "Right")

  local filter = self:addObject(name, libcore.StereoLadderHPF())
  connect(fundamental, "Out", filter, "Fundamental")
  connect(resonance, "Out", filter, "Resonance")
  connect(sum, "Out", filter, "V/Oct")
  return filter
end

function EQSweeps:lfo(name, zero, speed, scale)
  local gain = self:addObject(name .. "Gain", app.ConstantGain())
  gain:hardSet("Gain", scale)
  connect(speed, "Out", gain, "In")
  local sine = self:addObject(name, libcore.SineOscillator())
  connect(zero, "Out", sine, "V/Oct")
  connect(zero, "Out", sine, "Sync")
  connect(zero, "Out", sine, "Phase")
  connect(zero, "Out", sine, "Feedback")
  connect(gain, "Out", sine, "Fundamental")
  return sine
end

function EQSweeps:onLoadViews(objects, branches)
  local controls = {}
  local views = {expanded = {
    "res", "width", "speed", "amp", "center"
  }, collapsed = {}}

  controls.res = GainBias {
    button = "res",
    branch = branches.resonance,
    description = "Resonance",
    gainbias = objects.resonance,
    range = objects.resonanceRange,
    biasMap = Encoder.getMap("unit")
  }

  controls.width = GainBias {
    button = "width",
    branch = branches.width,
    description = "Width",
    gainbias = objects.width,
    range = objects.widthRange,
    biasMap = Encoder.getMap("[0,10]")
  }

  controls.speed = GainBias {
    button = "speed",
    branch = branches.speed,
    description = "Speed",
    gainbias = objects.speed,
    range = objects.speedRange,
    biasMap = Encoder.getMap("[0,2]")
  }

  controls.amp = GainBias {
    button = "amp",
    branch = branches.amp,
    description = "Amplitude",
    gainbias = objects.amp,
    range = objects.ampRange,
    biasMap = Encoder.getMap("[0,10]")
  }

  controls.center = GainBias {
    button = "center",
    description = "Center",
    branch = branches.center,
    gainbias = objects.center,
    range = objects.centerRange,
    biasMap = Encoder.getMap("filterFreq"),
    biasUnits = app.unitHertz,
    initialBias = 27.5,
    gainMap = Encoder.getMap("filterFreq"),
    scaling = app.octaveScaling
  }

  return controls, views
end

return EQSweeps
