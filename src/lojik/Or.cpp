#include <Or.h>
#include <od/constants.h>
#include <od/config.h>
#include <hal/ops.h>
#include <hal/simd.h>
#include <sense.h>

namespace lojik {
  Or::Or() {
    addInput(mIn);
    addInput(mGate);
    addOutput(mOut);

    addOption(mSense);
  }

  Or::~Or() { }

  void Or::process() {
    float *in  = mIn.buffer();
    float *gate = mGate.buffer();
    float *out   = mOut.buffer();

    float32x4_t sense = vdupq_n_f32(getSense(mSense));
    float32x4_t fZero = vdupq_n_f32(0.0f);
    uint32x4_t  uZero = vdupq_n_u32(0);

    for (int i = 0; i < FRAMELENGTH; i += 4) {
      float32x4_t l = vld1q_f32(in + i);
      float32x4_t r = vld1q_f32(gate + i);

      uint32x4_t lc = vcgtq_f32(l, sense);
      uint32x4_t rc = vcgtq_f32(r, fZero);

      // (l + r) > 0
      uint32x4_t _or = vcgtq_u32(vaddq_u32(lc, rc), uZero);
      vst1q_f32(out + i, vcvtq_n_f32_u32(_or, 32));
    }
  }
}