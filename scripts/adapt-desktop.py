#!/usr/bin/env python3
"""Keep vendor desktop settings while covering both supported DSI connector names."""
import pathlib
import sys
import xml.etree.ElementTree as ET

root = pathlib.Path(sys.argv[1])
path = root / 'etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml'
tree = ET.parse(path)
screen = tree.find("./property[@name='backdrop']/property[@name='screen0']")
assert screen is not None
for child in list(screen):
    screen.remove(child)
for output in ('DSI-1', 'DSI-2'):
    monitor = ET.SubElement(screen, 'property', name='monitor' + output, type='empty')
    for index in range(4):
        workspace = ET.SubElement(monitor, 'property', name=f'workspace{index}', type='empty')
        for name in ('color-style', 'image-style'):
            ET.SubElement(workspace, 'property', name=name, type='int', value='0')
        ET.SubElement(workspace, 'property', name='last-image', type='string', value='')
        color = ET.SubElement(workspace, 'property', name='rgba1', type='array')
        for value in ('0', '0', '0', '1'):
            ET.SubElement(color, 'value', type='double', value=value)
ET.indent(tree)
tree.write(path, encoding='UTF-8', xml_declaration=True)
