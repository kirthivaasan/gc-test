#include <stdint.h>
#include <stdio.h>

int main() {
  uint64_t x = 4;
  uint64_t result = 0;
  uint64_t result2 = 0;
  result = Impl_GarbledCircuit_square(x);
  result2 = Impl_GarbledCircuit_quad(x);
  printf("Square of %u is %u\n", x, result);
  printf("Quad of %u is %u\n", x, result2);
  return 0;
}
