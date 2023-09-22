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

local YLoop = Class {}
YLoop:include(Unit)

function YLoop:init(args)
  args.title = "Y Looper"
  args.mnemonic = "YLoop"
  args.version = 1
  Unit.init(self, args)
end

function YLoop:onLoadGraph(channelCount)
  local recordGate = self:addObject("recordGate", app.Comparator())
  recordGate:setOptionValue("Mode", app.COMPARATOR_GATE)
  self:addMonoBranch("recordGate", recordGate, "In", recordGate, "Out")
  
  local recordSlew = self:addObject("recordSlew", libcore.SlewLimiter())
  recordSlew:hardSet("Time", 0.25)
  
  connect(recordGate, "Out", recordSlew, "In")
  
  local inputL = self:addObject("inputL", app.Multiply())
  local inputR = self:addObject("inputR", app.Multiply())
  
  connect(self, "In1", inputL, "Left")
  connect(recordSlew, "Out", inputL, "Right")
  connect(self, "In2", inputR, "Left")
  connect(recordSlew, "Out", inputR, "Right")
  
  local delay = self:addObject("delay", libcore.Delay(2))
  delay:allocateTimeUpTo(60.0)
  connect(inputL, "Out", delay, "Left In")
  connect(inputR, "Out", delay, "Right In")
  connect(delay, "Left Out", self, "Out1")
  connect(delay, "Right Out", self, "Out2")
  
  local delayTimeFraction = self:addObject("delayTimeFraction", app.ParameterAdapter())
  self:addMonoBranch("delayTimeFraction", delayTimeFraction, "In", delayTimeFraction, "Out")
  tie(delay, "Left Delay", "function(f) return f * 1 end", delayTimeFraction, "Out")
  tie(delay, "Right Delay", "function(f) return f * 1 end", delayTimeFraction, "Out")

  local feedback = self:addObject("feedback", app.GainBias())
  local feedbackRange = self:addObject("feedbackRange", app.MinMax())
  connect(feedback, "Out", feedbackRange, "In")
  self:addMonoBranch("feedback", feedback, "In", feedback, "Out")
  connect(feedback, "Out", delay, "Feedback")
end

function YLoop:onLoadViews(objects, branches)
  local controls = {}
  local views = {
    expanded = {"record", "delay", "feedback"},
    collapsed = {}
  }

  controls.record = Gate {
    button = "record",
    description = "Record",
    branch = branches.recordGate,
    comparator = objects.recordGate
  }

  controls.delay = GainBias {
    button = "delay",
    description = "Fraction of total",
    branch = branches.delayTimeFraction,
    gainbias = objects.delayTimeFraction,
    range = objects.delayTimeFraction,
    biasMap = Encoder.getMap("unit"),
    initialBias = 1
  }

  controls.feedback = GainBias {
    button = "feedback",
    description = "Feedback",
    branch = branches.feedback,
    gainbias = objects.feedback,
    range = objects.feedbackRange,
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
