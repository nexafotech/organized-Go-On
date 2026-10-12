import xml.etree.ElementTree as ET

tree = ET.parse(r"C:\Users\Abishek\.gemini\antigravity\brain\7f90dbc7-1f76-43d0-a6a4-acccb732defd\retake_ui.xml")
for n in tree.iter("node"):
    txt = n.attrib.get("text", "")
    desc = n.attrib.get("content-desc", "")
    cls = n.attrib.get("class", "")
    bounds = n.attrib.get("bounds", "")
    if "Retake" in desc or "Retake" in txt or "Accept" in desc or "Accept" in txt:
        print(f"txt={txt!r} desc={desc!r} cls={cls!r} bounds={bounds}")
