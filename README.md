# Report Map (Google Maps) ![APEX Plugin](https://cdn.rawgit.com/Dani3lSun/apex-github-badges/b7e95341/badges/apex-plugin-badge.svg) ![APEX 18.2](https://github.com/Dani3lSun/apex-github-badges/blob/master/badges/apex-18_2-badge.svg)

**A Region plugin for Oracle Application Express**

This allows you to add a Google Map region to any page, showing a number of markers (pins) based on a query you specify. 

![plugin-reportmap-markers.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/src/plugin-reportmap-markers.png)

The user can click any marker to see a popup info window for it.

**Visualisation: Marker Clustering**

![plugin-reportmap-clustering.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/src/plugin-reportmap-clustering.png)

**Visualisation: Heatmap**

![plugin-reportmap-heatmap.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/src/plugin-reportmap-heatmap.png)

**Visualisation: Directions**

![plugin-reportmap-route.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/release-1-0/src/plugin-reportmap-route.png)

## DEMO ##

[https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64](https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64)

## PRE-REQUISITES ##

* Oracle Application Express 18.2 or later
* You need a [Google Maps API Key](https://developers.google.com/maps/documentation/javascript/get-api-key#get-an-api-key)

## INSTALLATION INSTRUCTIONS ##

**Warning:** if you are upgrading to v1.0 from any prior version, this is NOT a drop-in replacement; some changes may be required to your application to support it as a number of attributes have been removed. Also, the minimum requirement has changed to APEX 18.2.

1. Download the [latest release](https://github.com/jeffreykemp/jk64-plugin-reportmap/releases/latest)
2. Install the plugin to your application - **region_type_plugin_com_jk64_report_google_map.sql**
3. Supply your public **Google API Key** (Component Settings)
4. Add a region to the page, select type **JK64 Report Google Map [Plug-In]**
5. For **SQL Source**, enter a query with at least 4 columns (see example below)
6. Update the **Number of Rows** to a reasonable upper limit (default is 15, you probably want a higher limit)

**Sample query**

```sql
SELECT lat, lng, name, id FROM mydata
```

For more info including sample queries, plugin attributes and triggers, refer to the [WIKI](https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki).
