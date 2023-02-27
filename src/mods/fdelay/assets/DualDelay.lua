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

local DualDelay = Class {}
DualDelay:include(YBase)

function DualDelay:init(args)
  args.title = "Dual Filter Delay"
  args.mnemonic = "DD"
  args.version = 1
  YBase.init(self, args)
end

function DualDelay:onLoadGraph(channelCount)
  -- Common
  local inLevelAdapter = self:createAdapterControl("inLevelAdapter")
  local xfade = self:addObject("xfade", app.StereoCrossFade())
  local fader = self:createControl("fader", app.GainBias())
  connect(fader, "Out", xfade, "Fade")

  local delay = self:addObject("delay", libcore.Delay(2))
  delay:hardSet("Spread", 0.0)

  local feedbackGainAdapter = self:createAdapterControl("feedbackGainAdapter")
  local feedbackXMixAdapter = self:createAdapterControl("feedbackXMixAdapter")

  local tone = self:createControl("tone", app.GainBias())
  local eqHigh = self:createEqHighControl(tone)
  local eqMid = self:createEqMidControl()
  local eqLow = self:createEqLowControl(tone)

  local dc = self:addObject("dc", libcore.StereoFixedHPF())
  dc:hardSet("Cutoff", 10)

  -- Left Setup
  local inLevelL = self:addObject("inLevelL", app.ConstantGain())
  tie(inLevelL, "Gain", inLevelAdapter, "Out")

  local feedbackMixL = self:addObject("feedbackMixL", app.Sum())
  local feedbackGainL = self:addObject("feedbackGainL", app.ConstantGain())
  feedbackGainL:setClampInDecibels(-35.9)
  local feedbackFromRMixL = self:addObject("feedbackFromRMixL", app.Sum())
  local feedbackFromRGainL = self:addObject("feedbackFromRGainL", app.ConstantGain())
  tie(feedbackGainL, "Gain", "function(m,x) return m - (m * x) end", feedbackGainAdapter, "Out", feedbackXMixAdapter, "Out")
  tie(feedbackFromRGainL, "Gain", "function(m,x) return m * x end", feedbackGainAdapter, "Out", feedbackXMixAdapter, "Out")

  local limiterL = self:addObject("limiterL", libcore.Limiter())
  limiterL:setOptionValue("Type", libcore.LIMITER_CUBIC)

  local eqL = self:createEq("eqL", eqHigh, eqMid, eqLow)

  local delayLAdapter = self:createAdapterControl("delayLAdapter")
  tie(delay, "Left Delay", delayLAdapter, "Out")

  -- Right Setup
  local inLevelR = self:addObject("inLevelR", app.ConstantGain())
  tie(inLevelR, "Gain", inLevelAdapter, "Out")
  
  local feedbackMixR = self:addObject("feedbackMixR", app.Sum())
  local feedbackGainR = self:addObject("feedbackGainR", app.ConstantGain())
  feedbackGainR:setClampInDecibels(-35.9)
  local feedbackFromLMixR = self:addObject("feedbackFromLMixR", app.Sum())
  local feedbackFromLGainR = self:addObject("feedbackFromLGainR", app.ConstantGain())
  tie(feedbackGainR, "Gain", "function(m,x) return m - (m * x) end", feedbackGainAdapter, "Out", feedbackXMixAdapter, "Out")
  tie(feedbackFromLGainR, "Gain", "function(m,x) return m * x end", feedbackGainAdapter, "Out", feedbackXMixAdapter, "Out")
  
  local limiterR = self:addObject("limiterR", libcore.Limiter())
  limiterR:setOptionValue("Type", libcore.LIMITER_CUBIC)
  
  local eqR = self:createEq("eqR", eqHigh, eqMid, eqLow)
  
  local delayRAdapter = self:createAdapterControl("delayRAdapter")
  tie(delay, "Right Delay", delayRAdapter, "Out")

  -- Left Connect
  connect(self, "In1", xfade, "Left B")
  connect(self, "In1", inLevelL, "In")
  connect(inLevelL, "Out", feedbackMixL, "Left")
  connect(feedbackMixL, "Out", feedbackFromRMixL, "Left")
  connect(feedbackFromRMixL, "Out", eqL, "In")
  connect(eqL, "Out", limiterL, "In")
  connect(limiterL, "Out", dc, "Left In")
  connect(dc, "Left Out", delay, "Left In")
  connect(delay, "Left Out", feedbackGainL, "In")
  connect(delay, "Left Out", feedbackFromLGainR, "In")
  connect(delay, "Left Out", xfade, "Left A")
  connect(feedbackGainL, "Out", feedbackMixL, "Right")
  connect(feedbackFromLGainR, "Out", feedbackFromLMixR, "Right")
  connect(xfade, "Left Out", self, "Out1")

  -- Right Connect
  connect(self, "In2", xfade, "Right B")
  connect(self, "In2", inLevelR, "In")
  connect(inLevelR, "Out", feedbackMixR, "Left")
  connect(feedbackMixR, "Out", feedbackFromLMixR, "Left")
  connect(feedbackFromLMixR, "Out", eqR, "In")
  connect(eqR, "Out", limiterR, "In")
  connect(limiterR, "Out", dc, "Right In")
  connect(dc, "Right Out", delay, "Right In")
  connect(delay, "Right Out", feedbackGainR, "In")
  connect(delay, "Right Out", feedbackFromRGainL, "In")
  connect(delay, "Right Out", xfade, "Right A")
  connect(feedbackGainR, "Out", feedbackMixR, "Right")
  connect(feedbackFromRGainL, "Out", feedbackFromRMixL, "Right")
  connect(xfade, "Right Out", self, "Out2")
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

function DualDelay:setMaxDelayTime(secs)
  local requested = math.floor(secs + 0.5)
  local allocated = self.objects.delay:allocateTimeUpTo(requested)
  allocated = Utils.round(allocated, 1)
  local map = timeMap(allocated, 100)
  self.controls.delayL:setBiasMap(map)
  self.controls.delayR:setBiasMap(map)
end

local menu = {"setHeader", "set100ms", "set1s", "set10s", "set30s"}

function DualDelay:onShowMenu(objects, branches)
  local controls = {}
  local allocated = self.objects.delay:maximumDelayTime()
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

function DualDelay:onLoadViews(objects, branches)
  local controls = {}
  local views = {collapsed = {}}

  views.expanded = {
    "delayL", "delayR", "feedback", "xmix", "tone", "input", "wet"
  }
  controls.delayL = GainBias {
    button = "delay(L)",
    description = "Left Delay",
    branch = branches.delayLAdapter,
    gainbias = objects.delayLAdapter,
    range = objects.delayLAdapter,
    biasMap = timeMap(10, 100),
    biasUnits = app.unitSecs,
    initialBias = 0.5
  }

  controls.delayR = GainBias {
    button = "delay(R)",
    description = "Right Delay",
    branch = branches.delayRAdapter,
    gainbias = objects.delayRAdapter,
    range = objects.delayRAdapter,
    biasMap = timeMap(10, 100),
    biasUnits = app.unitSecs,
    initialBias = 0.7
  }

  controls.feedback = GainBias {
    button = "fdbk",
    description = "Feedback",
    branch = branches.feedbackGainAdapter,
    gainbias = objects.feedbackGainAdapter,
    range = objects.feedbackGainAdapter,
    biasMap = feedbackMap(),
    biasUnits = app.unitDecibels,
    initialBias = 1
  }
  controls.feedback:setTextBelow(-35.9, "-inf dB")

  controls.xmix = GainBias {
    button = "xmix",
    description = "Feedback Crossmix",
    branch = branches.feedbackXMixAdapter,
    gainbias = objects.feedbackXMixAdapter,
    range = objects.feedbackXMixAdapter,
    biasMap = Encoder.getMap("unit"),
    initialBias = 0
  }

  controls.tone = GainBias {
    button = "tone",
    description = "Tone",
    branch = branches.tone,
    gainbias = objects.tone,
    range = objects.toneRange,
    biasMap = Encoder.getMap("[-1,1]"),
    initialBias = 0
  }

  controls.input = GainBias {
    button = "input",
    description = "Delay Input Level",
    branch = branches.inLevelAdapter,
    gainbias = objects.inLevelAdapter,
    range = objects.inLevelAdapter,
    biasMap = Encoder.getMap("unit"),
    initialBias = 1
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

function DualDelay:onLoadFinished()
  self:setMaxDelayTime(10.0)
end

function DualDelay:serialize()
  local t = Unit.serialize(self)
  t.maximumDelayTime = self.objects.delay:maximumDelayTime()
  return t
end

function DualDelay:deserialize(t)
  local time = t.maximumDelayTime
  if time and time > 0 then
    self:setMaxDelayTime(time)
  end
  Unit.deserialize(self, t)
end

function DualDelay:onRemove()
  self.objects.delay:deallocate()
  Unit.onRemove(self)
end

return DualDelay
