-- Copyright (c) 2021, Jeroen Baekelandt
-- All rights reserved.
-- Redistribution and use in source and binary forms, with or without modification,
-- are permitted provided that the following conditions are met:
-- * Redistributions of source code must retain the above copyright notice, this
--   list of conditions and the following disclaimer.
-- * Redistributions in binary form must reproduce the above copyright notice, this
--   list of conditions and the following disclaimer in the documentation and/or
--   other materials provided with the distribution.
-- * Neither the name of the {organization} nor the names of its
--   contributors may be used to endorse or promote products derived from
--   this software without specific prior written permission.
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
-- ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
-- ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- Takes 9-10% CPU in stereo
local YBase = require "fdelay.YBase"
local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"
local libcore = require "core.libcore"
local Gate = require "Unit.ViewControl.Gate"
local GainBias = require "Unit.ViewControl.GainBias"
local Utils = require "Utils"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"

local TwoTapDelay = Class {}
TwoTapDelay:include(YBase)

function TwoTapDelay:init(args)
  args.title = "Two Tap Delay"
  args.mnemonic = "TTD"
  args.version = 1
  YBase.init(self, args)
end

function TwoTapDelay:onLoadGraph(channelCount)
  -- Stereo / General
  local delay1 = self:addObject("delay1", libcore.Delay(2))
  local delay2 = self:addObject("delay2", libcore.Delay(2))

  local xfade = self:addObject("xfade", app.StereoCrossFade())
  local fader = self:createControl("fader", app.GainBias())
  connect(fader, "Out", xfade, "Fade")

  local tapEdge = self:addObject("tapEdge", app.Comparator())
  self:addMonoBranch("clock", tapEdge, "In", tapEdge, "Out")
  local tap = self:createTap(tapEdge)
  local mult1 = self:createAdapterControl("mult1")
  local div1 = self:createAdapterControl("div1")
  local mult2 = self:createAdapterControl("mult2")
  local div2 = self:createAdapterControl("div2")

  local width = self:createAdapterControl("width")

  local feedbackGainAdapter = self:createAdapterControl("feedbackGainAdapter")

  local tone = self:createControl("tone", app.GainBias())
  local eqHigh = self:createEqHighControl(tone)
  local eqMid = self:createEqMidControl()
  local eqLow = self:createEqLowControl(tone)

  -- Left
  local delayMixL = self:addObject("delayMixL", app.Sum())
  local feedbackMixL = self:addObject("feedbackMixL", app.Sum())
  local feedbackGainL = self:addObject("feedbackGainL", app.ConstantGain())
  feedbackGainL:setClampInDecibels(-35.9)

  local panL = self:addObject("panL", app.ConstantGain())
  if channelCount == 1 then
    panL:hardSet("Gain", 1)
  end

  local limiterL = self:addObject("limiterL", libcore.Limiter())
  limiterL:setOptionValue("Type", libcore.LIMITER_CUBIC)
  local dc = self:addObject("dc", libcore.StereoFixedHPF())
  dc:hardSet("Cutoff", 10)

  local eqL = self:createEq("eqL", eqHigh, eqMid, eqLow)

  tie(feedbackGainL, "Gain", "function(f, w) return f / (2 - w) end", feedbackGainAdapter, "Out", width, "Out")
  tie(delay1, "Left Delay", "function(x, m, d) return x / m * d end", tap, "Derived Period", mult1, "Out", div1, "Out")
  tie(delay2, "Left Delay", "function(x, m, d) return x / m * d end", tap, "Derived Period", mult2, "Out", div2, "Out")

  connect(self, "In1", xfade, "Left B")
  connect(self, "In1", feedbackMixL, "Left")
  connect(feedbackMixL, "Out", eqL, "In")
  connect(eqL, "Out", delay1, "Left In")
  connect(eqL, "Out", delay2, "Left In")
  connect(delay1, "Left Out", delayMixL, "Left")
  connect(delay2, "Left Out", panL, "In")
  connect(panL, "Out", delayMixL, "Right")
  connect(delayMixL, "Out", feedbackGainL, "In")
  connect(delayMixL, "Out", xfade, "Left A")
  connect(feedbackGainL, "Out", dc, "Left In")
  connect(dc, "Left Out", limiterL, "In")
  connect(limiterL, "Out", feedbackMixL, "Right")
  connect(xfade, "Left Out", self, "Out1")

  -- Right
  if channelCount == 2 then
    local delayMixR = self:addObject("delayMixR", app.Sum())
    local feedbackMixR = self:addObject("feedbackMixR", app.Sum())
    local feedbackGainR = self:addObject("feedbackGainR", app.ConstantGain())
    feedbackGainR:setClampInDecibels(-35.9)

    local panR = self:addObject("panR", app.ConstantGain())
    tie(panL, "Gain", "function(x) return 1 - x end", width, "Out")
    tie(panR, "Gain", "function(x) return 1 - x end", width, "Out")

    local limiterR = self:addObject("limiterR", libcore.Limiter())
    limiterR:setOptionValue("Type", libcore.LIMITER_CUBIC)

    local eqR = self:createEq("eqR", eqHigh, eqMid, eqLow)

    tie(feedbackGainR, "Gain", "function(f, w) return f / (2 - w) end", feedbackGainAdapter, "Out", width, "Out")
    tie(delay1, "Right Delay", "function(x, m, d) return x / m * d end", tap, "Derived Period", mult1, "Out", div1, "Out")
    tie(delay2, "Right Delay", "function(x, m, d) return x / m * d end", tap, "Derived Period", mult2, "Out", div2, "Out")

    connect(self, "In2", xfade, "Right B")
    connect(self, "In2", feedbackMixR, "Left")
    connect(feedbackMixR, "Out", eqR, "In")
    connect(eqR, "Out", delay1, "Right In")
    connect(eqR, "Out", delay2, "Right In")
    connect(delay1, "Right Out", panR, "In")
    connect(panR, "Out", delayMixR, "Left")
    connect(delay2, "Right Out", delayMixR, "Right")
    connect(delayMixR, "Out", feedbackGainR, "In")
    connect(delayMixR, "Out", xfade, "Right A")
    connect(feedbackGainR, "Out", dc, "Right In")
    connect(dc, "Right Out", limiterR, "In")
    connect(limiterR, "Out", feedbackMixR, "Right")
    connect(xfade, "Right Out", self, "Out2")
  end
end

function TwoTapDelay:createTap(tapEdge)
  local tap = self:addObject("tap", libcore.TapTempo())
  tap:setBaseTempo(120)
  tap:hardSet("Multiplier", 1)
  tap:hardSet("Divider", 1)
  connect(tapEdge, "Out", tap, "In")
  return tap
end

local function feedbackMap()
  local map = app.LinearDialMap(-36, 6)
  map:setZero(-160)
  map:setSteps(6, 1, 0.1, 0.01);
  return map
end

function TwoTapDelay:setMaxDelayTime(secs)
  local requested = math.floor(secs + 0.5)
  self.objects.delay1:allocateTimeUpTo(requested)
  self.objects.delay2:allocateTimeUpTo(requested)
end

local menu = {"setHeader", "set100ms", "set1s", "set10s", "set30s"}

function TwoTapDelay:onShowMenu(objects, branches)
  local controls = {}
  local allocated = self.objects.delay1:maximumDelayTime()
  local allocated = self.objects.delay2:maximumDelayTime()
  allocated = Utils.round(allocated, 1)

  controls.setHeader = MenuHeader {
    description = string.format("Current Maximum Delay is %0.1fs.", allocated)
  }

  controls.set100ms = Task {
    description = "0.1s",
    task = function()
      self:setMaxDelayTime(0.1)
    end
  }

  controls.set1s = Task {
    description = "1s",
    task = function()
      self:setMaxDelayTime(1)
    end
  }

  controls.set10s = Task {
    description = "10s",
    task = function()
      self:setMaxDelayTime(10)
    end
  }

  controls.set30s = Task {
    description = "30s",
    task = function()
      self:setMaxDelayTime(30)
    end
  }

  return controls, menu
end

function TwoTapDelay:onLoadViews(objects, branches)
  local controls = {}
  local views = {collapsed = {}}

  if self.channelCount == 2 then
    views.expanded = {
      "clock", "mult1", "div1", "mult2", "div2", "feedback", "width", "tone", "wet"
    }
    controls.width = GainBias {
      button = "width",
      branch = branches.width,
      description = "Stereo Width",
      gainbias = objects.width,
      range = objects.width,
      biasMap = Encoder.getMap("unit")
    }
  else
    views.expanded = {
      "clock", "mult1", "div1", "mult2", "div2", "feedback", "tone", "wet"
    }
  end

  controls.clock = Gate {
    button = "clock",
    branch = branches.clock,
    description = "Clock",
    comparator = objects.tapEdge
  }

  controls.mult1 = GainBias {
    button = "mult1",
    branch = branches.mult1,
    description = "Clock Multiplier 1",
    gainbias = objects.mult1,
    range = objects.mult1,
    biasMap = Encoder.getMap("int[1,32]"),
    gainMap = Encoder.getMap("[-20,20]"),
    initialBias = 1,
    biasPrecision = 0
  }

  controls.div1 = GainBias {
    button = "div1",
    branch = branches.div1,
    description = "Clock Divider 1",
    gainbias = objects.div1,
    range = objects.div1,
    biasMap = Encoder.getMap("int[1,32]"),
    gainMap = Encoder.getMap("[-20,20]"),
    initialBias = 1,
    biasPrecision = 0
  }

  controls.mult2 = GainBias {
    button = "mult2",
    branch = branches.mult2,
    description = "Clock Multiplier 2",
    gainbias = objects.mult2,
    range = objects.mult2,
    biasMap = Encoder.getMap("int[1,32]"),
    gainMap = Encoder.getMap("[-20,20]"),
    initialBias = 2,
    biasPrecision = 0
  }

  controls.div2 = GainBias {
    button = "div2",
    branch = branches.div2,
    description = "Clock Divider 2",
    gainbias = objects.div2,
    range = objects.div2,
    biasMap = Encoder.getMap("int[1,32]"),
    gainMap = Encoder.getMap("[-20,20]"),
    initialBias = 3,
    biasPrecision = 0
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
    biasMap = Encoder.getMap("unit")
  }

  self:setMaxDelayTime(1.0)

  return controls, views
end

function TwoTapDelay:serialize()
  local t = Unit.serialize(self)
  t.maximumDelayTime = self.objects.delay1:maximumDelayTime()
  return t
end

function TwoTapDelay:deserialize(t)
  local time = t.maximumDelayTime
  if time and time > 0 then
    self:setMaxDelayTime(time)
  end
  Unit.deserialize(self, t)
end

function TwoTapDelay:onRemove()
  self.objects.delay1:deallocate()
  self.objects.delay2:deallocate()
  Unit.onRemove(self)
end

return TwoTapDelay
