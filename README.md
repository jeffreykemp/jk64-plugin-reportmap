# Report Map (Google Maps) ![APEX Plugin](https://cdn.rawgit.com/Dani3lSun/apex-github-badges/b7e95341/badges/apex-plugin-badge.svg) ![APEX 18.2](https://github.com/Dani3lSun/apex-github-badges/blob/master/badges/apex-18_2-badge.svg)

**A Region plugin for Oracle Application Express**

This allows you to add a Google Map region to any page, showing a number of markers (pins) based on a query you specify. The plugin provides a rich array of built-in features, as well as giving access to the underlying Google Maps object so you can customise it with the behaviour you need.

![plugin-reportmap-markers.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/images/plugin-reportmap-markers.png)

The user can click any marker to see a popup info window for it.

### Visualisation: Marker Clustering

![plugin-reportmap-clustering.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/images/plugin-reportmap-clustering.png)

If many pins are too close together, Marker Clustering merges them into a single cluster; the number indicates how many pins are at that location. As the user zooms in or out, the clusters will split up or merge as needed.

### Visualisation: Heatmap

![plugin-reportmap-heatmap.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/images/plugin-reportmap-heatmap.png)

This is suitable for a large volume of data points. Each data point can have a "weight" which indicates the magnitude of some measure.

### Visualisation: Directions

![plugin-reportmap-route.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/images/plugin-reportmap-route.png)

Up to 10 points (origin, destination, plus up to 8 waypoints) may be supplied to derive a route. Google Maps can generate a route for Driving, Walking, Bicycling, or Transit (public transport). The plugin can also get the calculated total Distance and Time for the route.

## DEMO

[https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64](https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64)

## PRE-REQUISITES

* Oracle Application Express 18.2 or later
* You need a [Google Maps API Key](https://developers.google.com/maps/documentation/javascript/get-api-key#get-an-api-key)

## INSTALLATION INSTRUCTIONS

**Warning:** if you are upgrading to v1.0 from any prior version, this is NOT a drop-in replacement; some changes may be required to your application to support it as a number of attributes have been removed. Also, the minimum requirement has changed to APEX 18.2.

1. Download the [latest release](https://github.com/jeffreykemp/jk64-plugin-reportmap/releases/latest)
2. Install the plugin to your application - **region_type_plugin_com_jk64_report_google_map_r1.sql**
3. Supply your public **Google API Key** (Component Settings)
4. Add a region to the page, select type **JK64 Report Google Map R1 [Plug-In]**
5. For **SQL Source**, enter a query with at least 4 columns (see example below)

**IF YOU ARE UPGRADING** from an earlier release, refer to the **[Upgrade Notes](https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki/Upgrading)**.

**Sample query**

```sql
SELECT lat, lng, name, id FROM mydata
```

For more info including sample queries, plugin attributes and triggers, refer to the [WIKI](https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki).
