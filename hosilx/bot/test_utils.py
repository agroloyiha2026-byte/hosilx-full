from utils import num


def test_valid():
    assert num("12 500") == 12500.0
    assert num("3,5") == 3.5


def test_invalid():
    assert num("abc") is None
    assert num("0") is None
    assert num("-4") is None
    assert num(None) is None
