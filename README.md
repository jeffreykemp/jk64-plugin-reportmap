# Report Map (Google Maps) ![APEX Plugin](https://cdn.rawgit.com/Dani3lSun/apex-github-badges/b7e95341/badges/apex-plugin-badge.svg) ![APEX 5.0](https://cdn.rawgit.com/jeffreykemp/apex-github-badges/master/badges/apex-5.0-badge.svg)

**A Region plugin for Oracle Application Express**

This allows you to add a Google Map region to any page, showing a number of markers (pins) based on a query you specify. 

![plugin-reportmap-preview.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/master/src/plugin-reportmap-preview.png)

The user can click any marker to see a popup info window for it. You can have the region synchronize the map with an item you nominate - if so, the corresponding ID for the marker they click will be copied to the item.

## DEMO ##

[https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64](https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP&c=JK64)

## PRE-REQUISITES ##

* [Oracle Application Express 5.0.4](https://apex.oracle.com)

## INSTALLATION INSTRUCTIONS ##

1. Download the [latest release](https://github.com/jeffreykemp/jk64-plugin-reportmap/releases/latest)
2. Install the plugin to your application - **region_type_plugin_com_jk64_report_google_map.sql**
3. *(optional)* Supply your **Google API Key** (NOTE: the plugin is usable without one)
4. Add a region to the page, select type **JK64 Report Google Map [Plug-In]**
5. For **SQL Source**, enter a query with at least 4 columns (see example below)
6. Update the **Number of Rows** to a reasonable upper limit (default is 15, you probably want a higher limit)

**Sample query**

```sql
SELECT lat, lng, name, id FROM mydata
```

For more info including version history and plugin references, refer to the [WIKI](https://github.com/jeffreykemp/jk64-plugin-reportmap/wiki).
