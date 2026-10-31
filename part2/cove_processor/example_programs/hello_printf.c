#include <stdio.h>

int main() {
  int result;

  result = printf("Hello World!!!\n\r");
  result = printf("This is the printf function running on the Trireme Platform.\n\r");
  result = printf("The printf function just returned %d.\n\r", result);

  return result;

}
