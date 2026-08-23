#include "acme_lib_utils.hpp"

#include <iostream>

int main() {
  std::cout << acme::format_label("slug", acme::slugify("  Acme Demo App  ")) << '\n';
  return 0;
}
