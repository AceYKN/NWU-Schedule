"""Rebuild offline test fonts with fontTools; does not change application assets."""

from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.request import urlopen
import hashlib

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

REVISION = "24ecb0bbdc3a52d6fddef160b769c61463f455d9"
BASE = f"https://raw.githubusercontent.com/google/fonts/{REVISION}/ofl/notosanssc"
ROOT = Path(__file__).resolve().parent.parent
DESTINATION = ROOT / "test" / "fonts"


def main():
    characters = set(range(0x20, 0x7F))
    # Common simplified Chinese, punctuation and every character in our fixtures.
    for first in range(0xA1, 0xF8):
        for second in range(0xA1, 0xFF):
            try:
                characters.update(map(ord, bytes((first, second)).decode("gb2312")))
            except UnicodeDecodeError:
                pass
    for directory in ("lib", "test"):
        for path in sorted((ROOT / directory).rglob("*")):
            if path.suffix in (".dart", ".json", ".html"):
                characters.update(map(ord, path.read_text(encoding="utf-8-sig")))

    DESTINATION.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="nwu-golden-font-") as temporary:
        source = Path(temporary) / "NotoSansSC.ttf"
        with urlopen(f"{BASE}/NotoSansSC%5Bwght%5D.ttf") as response:
            source.write_bytes(response.read())
        source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        font = TTFont(source, recalcTimestamp=False)
        options = subset.Options()
        options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=characters)
        subsetter.subset(font)
        reduced = Path(temporary) / "subset.ttf"
        font.save(reduced)
        for weight, style in ((400, "Regular"), (700, "Bold")):
            face = TTFont(reduced, recalcTimestamp=False)
            instantiateVariableFont(face, {"wght": weight}, inplace=True)
            # Give the modified subset its own family and PostScript names.
            for record in face["name"].names:
                replacement = {
                    1: "NwuScheduleGolden", 2: style,
                    3: f"NwuScheduleGolden-{style}",
                    4: f"NwuScheduleGolden {style}",
                    6: f"NwuScheduleGolden-{style}",
                }.get(record.nameID)
                if replacement is not None:
                    record.string = replacement.encode(record.getEncoding())
            destination = DESTINATION / f"NwuScheduleGolden-{style}.ttf"
            face.save(destination)
            print(f"{destination.name}: {destination.stat().st_size} bytes")
        print(f"Source SHA-256: {source_hash}")
    with urlopen(f"{BASE}/OFL.txt") as response:
        (DESTINATION / "OFL.txt").write_bytes(response.read())


if __name__ == "__main__":
    main()
