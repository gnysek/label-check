"""Dołącza partię dodatków z tools/data/*.txt do assets/additives.json.

Format wiersza: KOD|Nazwa|A/R/B|[uwaga]|[alias;alias]
A = dozwolony, R = dozwolony z ograniczeniami, B = brak na liście UE.
Istniejące wpisy nie są nadpisywane. Statusy ogólne - nie zastępują bazy UE.
"""
import json, re, sys, pathlib

NOTES = {
    "A": "Dozwolony; warunki użycia zależą od kategorii żywności.",
    "R": "Dozwolony w wybranych kategoriach lub z limitami.",
    "B": "Brak na unijnej liście dozwolonych dodatków do żywności.",
}
STATUS = {"A": "allowed", "R": "restricted", "B": "banned"}
path = pathlib.Path("assets/additives.json")
d = json.loads(path.read_text(encoding="utf-8"))
have = {a["code"] for a in d["additives"]}
added = 0
for f in sys.argv[1:]:
    for line in pathlib.Path(f).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        p = line.split("|")
        code, name, st = p[0], p[1], p[2]
        note = p[3] if len(p) > 3 and p[3] else NOTES[st]
        if code in have:
            continue
        e = dict(code=code, name=name, status=STATUS[st], note=note,
                 source="Rozporządzenie (WE) nr 1333/2008 (dane ogólne, zweryfikuj w bazie UE)")
        if len(p) > 4 and p[4]:
            e["aliases"] = p[4].split(";")
        d["additives"].append(e)
        have.add(code)
        added += 1
d["additives"].sort(key=lambda x: (int(re.search(r"\d+", x["code"]).group()), x["code"]))
path.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
print("dodano", added, "razem", len(d["additives"]))
