# Report Google Map region plugin for Oracle Application Express. #

This allows you to add a Google Map region to any page, showing a number of markers (pins) based on a query you specify.

** PLEASE send me your feedback! [jeffrey.kemp@jk64.com](mailto:jeffrey.kemp@jk64.com) **

![plugin-reportmap-preview.png](https://raw.githubusercontent.com/jeffreykemp/jk64-plugin-reportmap/master/plugin-reportmap-preview.png)

The user can click any marker to see a popup info window for it. You can have the region synchronize the map with an item you nominate - if so, the corresponding ID for the marker they click will be copied to the item.

## DEMO ##

[https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP](https://apex.oracle.com/pls/apex/f?p=JK64_REPORT_MAP)

## INSTALLATION INSTRUCTIONS ##

1. Upload the plugin to your application
2. Add a region to the page, select type JK64 Report Google Map [plugin]
3. For SQL Source, enter a query with exactly 5 columns (see example below)
3. (optional) Synchronize the map with an item on your page.

**Sample query**

```
#!sql
SELECT lat, lng, name, id, info FROM mydata
```