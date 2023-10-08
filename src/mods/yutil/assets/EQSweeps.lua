local libcore = require "core.libcore"
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"

local EQSweeps = Class {}
EQSweeps:include(Unit)

function EQSweeps:init(args)
  args.title = "EQ Sweeps"
  args.mnemonic = "EQS"
  args.version = 1
  Unit.init(self, args)
end

function EQSweeps:onLoadGraph(channelCount)
  local zero = self:addObject("zero", app.Constant())
  zero:hardSet("Value", 0.0)
  local one = self:addObject("one", app.Constant())
  one:hardSet("Value", 1.0)
 
  local eqL = self:addObject("eqL", libcore.Equalizer3())
  connect(zero, "Out", eqL, "Low Gain")
  connect(one, "Out", eqL, "Mid Gain")
  connect(zero, "Out", eqL, "High Gain")

  local eqLL = self:addObject("eqLL", libcore.Equalizer3())
  connect(zero, "Out", eqLL, "Low Gain")
  connect(one, "Out", eqLL, "Mid Gain")
  connect(zero, "Out", eqLL, "High Gain")

  local eqLR = self:addObject("eqLR", libcore.Equalizer3())
  connect(zero, "Out", eqLR, "Low Gain")
  connect(one, "Out", eqLR, "Mid Gain")
  connect(zero, "Out", eqLR, "High Gain")

  local eqRL = self:addObject("eqRL", libcore.Equalizer3())
  connect(zero, "Out", eqRL, "Low Gain")
  connect(one, "Out", eqRL, "Mid Gain")
  connect(zero, "Out", eqRL, "High Gain")

  local eqRR = self:addObject("eqRR", libcore.Equalizer3())
  connect(zero, "Out", eqRR, "Low Gain")
  connect(one, "Out", eqRR, "Mid Gain")
  connect(zero, "Out", eqRR, "High Gain")
 
  local eqR = self:addObject("eqR", libcore.Equalizer3())
  connect(zero, "Out", eqR, "Low Gain")
  connect(one, "Out", eqR, "Mid Gain")
  connect(zero, "Out", eqR, "High Gain")

  local sineLAdapter = self:sweeper("sineL", zero, 0.43)
  local sineLLAdapter = self:sweeper("sineLL", zero, 0.47)
  local sineRRAdapter = self:sweeper("sineRR", zero, 0.53)
  local sineRAdapter = self:sweeper("sineR", zero, 0.59)

  tie(eqL, "Low Freq", "function(f) return  (f + 1) * 2000 + 20 end", sineLAdapter, "Out")
  tie(eqL, "High Freq", "function(f) return (f + 1) * 2000 + 4000  end", sineLAdapter, "Out")
  tie(eqR, "Low Freq", "function(f) return  (f + 1) * 2000 + 20  end", sineRAdapter, "Out")
  tie(eqR, "High Freq", "function(f) return (f + 1) * 2000 + 4000  end", sineRAdapter, "Out")

  connect(self, "In1", eqL, "In")
  connect(eqL, "Out", self, "Out1")
  connect(self, "In2", eqR, "In")
  connect(eqR, "Out", self, "Out2")
end

function EQSweeps:sweeper(name, zero, freq)
  local sineFreq = self:addObject(name .. "Freq", app.Constant())
  sineFreq:hardSet("Value", freq)

  local sine = self:addObject(name, libcore.SineOscillator())
  connect(zero, "Out", sine, "V/Oct")
  connect(zero, "Out", sine, "Sync")
  connect(zero, "Out", sine, "Phase")
  connect(zero, "Out", sine, "Feedback")
  connect(sineFreq, "Out", sine, "Fundamental")

  local sineAdapter = self:addObject(name .. "Adapter", app.ParameterAdapter())
  sineAdapter:hardSet("Gain", 1.0)
  connect(sine, "Out", sineAdapter, "In")
  return sineAdapter
end

function EQSweeps:onLoadViews(objects, branches)
  local controls = {}
  local views = {expanded = {}, collapsed = {}}
  return controls, views
end

return EQSweeps
