import xml.etree.ElementTree as ET

tree = ET.parse(r"C:\Users\Abishek\.gemini\antigravity\brain\7f90dbc7-1f76-43d0-a6a4-acccb732defd\cam_ui.xml")
for n in tree.iter("node"):
    txt = n.attrib.get("text", "")
    desc = n.attrib.get("content-desc", "")
    cls = n.attrib.get("class", "")
    bounds = n.attrib.get("bounds", "")
    if txt or desc or "Button" in cls or "Image" in cls:
        print(f"txt={txt!r} desc={desc!r} cls={cls!r} bounds={bounds}")
