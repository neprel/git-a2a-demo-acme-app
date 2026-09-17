from app import describe


def test_uses_python_implementation() -> None:
    assert describe("  Ada   Lovelace  ") == "Ada Lovelace"


if __name__ == "__main__":
    test_uses_python_implementation()
