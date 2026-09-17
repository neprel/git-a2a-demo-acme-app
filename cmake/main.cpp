#include "acme_lib_utils.hpp"

#include <iostream>

int main(int argc, char* argv[]) {
  const std::string value = argc > 1 ? argv[1] : "  Ada   Lovelace  ";
  std::cout << acme::format_display_name(value) << '\n';
  return 0;
}
