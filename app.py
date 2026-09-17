import sys

from acme_lib_utils import format_display_name


def describe(value: str) -> str:
    return format_display_name(value)


if __name__ == "__main__":
    print(describe(sys.argv[1] if len(sys.argv) > 1 else "  Ada   Lovelace  "))
