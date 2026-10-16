def num(text):
    """Musbat son qaytaradi, aks holda None."""
    try:
        v = float((text or "").replace(" ", "").replace(",", "."))
        return v if v > 0 else None
    except ValueError:
        return None
