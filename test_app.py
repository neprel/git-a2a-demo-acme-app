from app import describe


def test_uses_python_implementation() -> None:
    assert describe("  Acme Demo App  ") == "slug: acme-demo-app"
