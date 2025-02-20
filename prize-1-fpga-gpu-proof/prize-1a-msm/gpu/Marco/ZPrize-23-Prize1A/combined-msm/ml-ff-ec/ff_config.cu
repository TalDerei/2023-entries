#include <cstdint>

namespace bls12_377 {
__device__ __constant__ uint32_t inv_p = 0xffffffff;
__device__ __constant__ uint32_t inv_q = 0xffffffff;
} // namespace bls12_377

namespace bls12_381 {
    __device__ __constant__ uint32_t inv_p = 0xfffcfffd;
    __device__ __constant__ uint32_t inv_q = 0xffffffff;
} // namespace bls12_377