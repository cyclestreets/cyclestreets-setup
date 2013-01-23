How to configure OpenLayers

This file documents how ...

http://docs.openlayers.org/library/deploying.html

.. was used to configure OpenLayers, in July 2012.

The result of rgrep "new OpenLayers" /websites/www/content/ finds these classes:

Filter: *.php
=============
OpenLayers.Format.GeoJSON
OpenLayers.Projection
OpenLayers.Layer.Vector
OpenLayers.LonLat


Filter: *.js
============
OpenLayers.Bounds
OpenLayers.Control.Click
OpenLayers.Control.DragFeature
OpenLayers.Control.DrawBearing
OpenLayers.Control.DrawFeature
OpenLayers.Control.Hover
OpenLayers.Control.ModifyFeature
OpenLayers.Control.SelectFeature
OpenLayers.Feature.Vector
OpenLayers.Format.GML
OpenLayers.Geometry.LineString
OpenLayers.Geometry.Point
OpenLayers.Handler.Click
OpenLayers.Handler.Hover
OpenLayers.Handler.Point
OpenLayers.Icon
OpenLayers.Layer.GML
OpenLayers.Layer.Markers
OpenLayers.Layer.Vector
OpenLayers.LonLat
OpenLayers.Marker
OpenLayers.Pixel
OpenLayers.Popup.FramedCloud
OpenLayers.Projection
OpenLayers.Protocol.HTTP
OpenLayers.Rule
OpenLayers.Size
OpenLayers.Strategy.BBOX
OpenLayers.Style
OpenLayers.StyleMap


OpenLayers.Map
OpenLayers.Control.LayerSwitcher
OpenLayers.Control.Permalink
OpenLayers.Control.ScaleLine
OpenLayers.Control.Attribution
OpenLayers.Control.PanZoomBar
OpenLayers.Control.PZ
OpenLayers.Control.Navigation
OpenLayers.Control.MousePosition
OpenLayers.Layer.OSM
OpenLayers.Layer.Google
OpenLayers.Layer.Bing


Look at build/mobile.cfg for clues on how to incorporate renderers
=============
OpenLayers/Renderer/Elements.js
OpenLayers/Renderer/VML.js
OpenLayers/Renderer/SVG.js
OpenLayers/Renderer/Canvas.js


Troubleshooting
====
Also add:
OpenLayers/Layer/Google/v3.js
OpenLayers/Filter/Comparison.js
OpenLayers/Handler/Path.js

These are CycleStreets specific:
OpenLayers/Control/DrawBearing.js

Grep "OpenLayers" *.js
====
OpenLayers.Util.onImageLoadError
OpenLayers.Control.ArgParser, {CLASS_NAME: 'CustomArgParser4OSM'}),

This did track down a missing entry:

Bug in OpenLayers: this entry: * @requires OpenLayers/Protocol.js Must be added to: lib/OpenLayers/Protocol/HTTP.js

As recorded at: http://dev.cyclestreets.net/changeset/9338/project

Use the run.sh script to do the build.

# End of document
