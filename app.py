from acme_lib_utils import format_label, slugify


def describe(value: str) -> str:
    return format_label("slug", slugify(value))


if __name__ == "__main__":
    print(describe("  Acme Demo App  "))
