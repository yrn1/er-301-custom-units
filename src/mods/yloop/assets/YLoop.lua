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
local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"
local libcore = require "core.libcore"
local Gate = require "Unit.ViewControl.Gate"
local GainBias = require "Unit.ViewControl.GainBias"
local libyloop = require "yloop.libyloop"

local YLoop = Class {}
YLoop:include(Unit)

function YLoop:init(args)
  args.title = "Y Looper"
  args.mnemonic = "YLoop"
  args.version = 1

  self.maxDelay = 60.0

  Unit.init(self, args)
end

function YLoop:onLoadGraph(channelCount)
  -- controls
  local recordGate = self:addObject("recordGate", app.Comparator())
  recordGate:setGateMode()
  self:addMonoBranch("recordGate", recordGate, "In", recordGate, "Out")
  
  local sizeFraction = self:addObject("sizeFraction", app.ParameterAdapter())
  self:addMonoBranch("sizeFraction", sizeFraction, "In", sizeFraction, "Out")

  local rlFraction = self:addObject("rlFraction", app.ParameterAdapter())
  self:addMonoBranch("rlFraction", rlFraction, "In", rlFraction, "Out")

  local feedback = self:addObject("feedback", app.GainBias())
  local feedbackRange = self:addObject("feedbackRange", app.MinMax())
  connect(feedback, "Out", feedbackRange, "In")
  self:addMonoBranch("feedback", feedback, "In", feedback, "Out")

  local suppression = self:addObject("suppression", app.ParameterAdapter())
  self:addMonoBranch("suppression", suppression, "In", suppression, "Out")

  -- Input and recording
  local recordSlew = self:addObject("recordSlew", libcore.SlewLimiter())
  recordSlew:hardSet("Time", 0.25)
  
  connect(recordGate, "Out", recordSlew, "In")
  
  local inputL = self:addObject("inputL", app.Multiply())
  local inputR = self:addObject("inputR", app.Multiply())
  
  connect(self, "In1", inputL, "Left")
  connect(recordSlew, "Out", inputL, "Right")
  connect(self, "In2", inputR, "Left")
  connect(recordSlew, "Out", inputR, "Right")

  -- Feedback suppression
  local suppFBIn = self:addObject("suppFBIn", app.Sum())
  local suppFBEnv = self:addObject("suppFBEnv", libcore.EnvelopeFollower())
  suppFBEnv:hardSet("Attack Time", 0.050)
  suppFBEnv:hardSet("Release Time", 0.200)
  local suppFBLevel = self:addObject("suppFBLevel", app.Multiply())
  local suppFBScale = self:addObject("suppFBScale", app.GainBias())
  suppFBScale:hardSet("Gain", -5.0)
  suppFBScale:hardSet("Bias", 1.0)
  local suppFB = self:addObject("suppFB", libcore.Clipper(0.0, 1.0))
  local feedbackSupp = self:addObject("feedbackSupp", app.Multiply())
  connect(inputL, "Out", suppFBIn, "Left")
  connect(inputR, "Out", suppFBIn, "Right")
  connect(suppFBIn, "Out", suppFBEnv, "In")
  connect(suppFBEnv, "Out", suppFBLevel, "Left")
  connect(suppression, "Out", suppFBLevel, "Right")
  connect(suppFBLevel, "Out", suppFBScale, "In")
  connect(suppFBScale, "Out", suppFB, "In")
  connect(suppFB, "Out", feedbackSupp, "Left")
  connect(feedback, "Out", feedbackSupp, "Right")

  -- Output suppression
  local suppOutIn = self:addObject("suppOutIn", app.Sum())
  local suppOutEnv = self:addObject("suppOutEnv", libcore.EnvelopeFollower())
  suppOutEnv:hardSet("Attack Time", 0.050)
  suppOutEnv:hardSet("Release Time", 0.200)
  local suppOutLevel = self:addObject("suppOutLevel", app.Multiply())
  local suppOutScale = self:addObject("suppOutScale", app.GainBias())
  suppOutScale:hardSet("Gain", -5.0)
  suppOutScale:hardSet("Bias", 1.0)
  local suppOut = self:addObject("suppOut", libcore.Clipper(0.0, 1.0))
  connect(self, "In1", suppOutIn, "Left")
  connect(self, "In2", suppOutIn, "Right")
  connect(suppOutIn, "Out", suppOutEnv, "In")
  connect(suppOutEnv, "Out", suppOutLevel, "Left")
  connect(suppression, "Out", suppOutLevel, "Right")
  connect(suppOutLevel, "Out", suppOutScale, "In")
  connect(suppOutScale, "Out", suppOut, "In")
  
  -- onceRecordGate == recordGate only the first time, until reset by making feedback 0
  local negRecordGate = self:addObject("negRecordGate", app.ConstantGain())
  negRecordGate:hardSet("Gain", -1.0)
  local negFeedback = self:addObject("negFeedback", app.ConstantGain())
  negFeedback:hardSet("Gain", -1.0)
  local onceTriggerComparator = self:addObject("onceTriggerComparator", app.Comparator())
  onceTriggerComparator:setTriggerOnRiseMode()
  onceTriggerComparator:hardSet("Threshold", -0.1)
  local onceResetComparator = self:addObject("onceResetComparator", app.Comparator())
  onceResetComparator:setTriggerOnRiseMode()
  onceResetComparator:hardSet("Threshold", -0.1)
  local onceCounter = self:addObject("onceCounter", libcore.Counter())
  onceCounter:hardSet("Step Size", 1)
  onceCounter:hardSet("Start", 1)
  onceCounter:hardSet("Value", 1)
  onceCounter:hardSet("Finish", 0)
  onceCounter:setOptionValue("Wrap", app.CHOICE_NO)
  onceCounter:setOptionValue("Processing Rate", app.PER_FRAME)
  local onceRecordGate = self:addObject("onceRecordGate", app.Multiply())
  connect(recordGate, "Out", negRecordGate, "In")
  connect(negRecordGate, "Out", onceTriggerComparator, "In")
  connect(feedback, "Out", negFeedback, "In")
  connect(negFeedback, "Out", onceResetComparator, "In")
  connect(onceTriggerComparator, "Out", onceCounter, "In")
  connect(onceResetComparator, "Out", onceCounter, "Reset")
  connect(recordGate, "Out", onceRecordGate, "Left")
  connect(onceCounter, "Out", onceRecordGate, "Right")

  -- timing first recording length
  local stopwatch = self:addObject("stopwatch", libyloop.Stopwatch())
  stopwatch:hardSet("Max", self.maxDelay)
  connect(onceRecordGate, "Out", stopwatch, "In")

  -- hooking it all up to the delay lines
  local delay = self:addObject("delay", libcore.Delay(2))
  local outL = self:addObject("outL", app.Multiply())
  local outR = self:addObject("outR", app.Multiply())
  delay:allocateTimeUpTo(self.maxDelay)
  connect(inputL, "Out", delay, "Left In")
  connect(inputR, "Out", delay, "Right In")
  connect(delay, "Left Out", outL, "Left")
  connect(delay, "Right Out", outR, "Left")
  connect(suppOut, "Out", outL, "Right")
  connect(suppOut, "Out", outR, "Right")
  connect(outL, "Out", self, "Out1")
  connect(outR, "Out", self, "Out2")

  tie(delay, "Left Delay", "function(t, f) return math.max(0.01, t * f) end",
    stopwatch, "Out", sizeFraction, "Out")
  tie(delay, "Right Delay", "function(t, f, r, o) return math.max(0.01, t * f * math.max(o, r)) end",
    stopwatch, "Out", sizeFraction, "Out", rlFraction, "Out", onceCounter, "Value")

  connect(feedbackSupp, "Out", delay, "Feedback")
end

function YLoop:onLoadViews(objects, branches)
  local controls = {}
  local views = {
    expanded = {"record", "delay", "rl", "feedback", "suppression"},
    collapsed = {}
  }

  controls.record = Gate {
    button = "record",
    description = "Record",
    branch = branches.recordGate,
    comparator = objects.recordGate
  }

  controls.delay = GainBias {
    button = "size",
    description = "Size fraction",
    branch = branches.sizeFraction,
    gainbias = objects.sizeFraction,
    range = objects.sizeFraction,
    biasMap = Encoder.getMap("unit"),
    initialBias = 1
  }

  controls.rl = GainBias {
    button = "r/l",
    description = "R/L fraction",
    branch = branches.rlFraction,
    gainbias = objects.rlFraction,
    range = objects.rlFraction,
    biasMap = Encoder.getMap("unit"),
    initialBias = 1
  }

  controls.feedback = GainBias {
    button = "fdbk",
    description = "Feedback",
    branch = branches.feedback,
    gainbias = objects.feedback,
    range = objects.feedbackRange,
    biasMap = Encoder.getMap("unit"),
    initialBias = 1
  }

  controls.suppression = GainBias {
    button = "supp",
    description = "Suppression",
    branch = branches.suppression,
    gainbias = objects.suppression,
    range = objects.suppression,
    biasMap = Encoder.getMap("unit"),
    initialBias = 1
  }

  return controls, views
end

function YLoop:onRemove()
  self.objects.delay:deallocate()
  Unit.onRemove(self)
end

return YLoop
