import os
ROOT = r"E:\Arxangel\GameDev\BeastRoad\game"

def patch(rel, pairs):
    path = os.path.join(ROOT, rel)
    raw = open(path, "rb").read()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8").replace("\r\n", "\n")
    for old, new in pairs:
        count = text.count(old)
        assert count == 1, (rel, count, old[:80])
        text = text.replace(old, new)
    if crlf:
        text = text.replace("\n", "\r\n")
    open(path, "wb").write(text.encode("utf-8"))
    print("patched", rel, len(pairs), "crlf" if crlf else "lf")
