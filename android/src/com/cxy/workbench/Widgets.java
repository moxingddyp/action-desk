package com.cxy.workbench;
import android.app.*;
import android.appwidget.*;
import android.content.*;
import android.os.SystemClock;
import android.widget.RemoteViews;
import org.json.*;

final class Widgets {
 static final java.util.Map<Integer,String> LAST_ACTION=new java.util.HashMap<>();
 static PendingIntent activity(Context c,String tab){Intent i=new Intent(c,MainActivity.class).putExtra("tab",tab).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TOP);return PendingIntent.getActivity(c,tab.equals("devices")?101:100,i,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);}
 static void updateAll(Context c){update(c,ActionWidget.class,false);DeviceWidgets.updateAll(c);}
 static void update(Context c,Class<?> provider,boolean devices){if(devices){DeviceWidgets.updateAll(c);return;}AppWidgetManager manager=AppWidgetManager.getInstance(c);JSONObject data=Store.read(c,"actions");String source=data==null?"":String.valueOf(data.optJSONArray("items"))+String.valueOf(data.optJSONArray("calendarEvents"))+data.optString("generatedAt","");for(int id:manager.getAppWidgetIds(new ComponentName(c,provider))){String key=source.hashCode()+"|"+Store.prefs(c).getInt("widget-page-"+id,0)+"|"+Store.prefs(c).getString("widget-mode-"+id,"ring")+"|"+Store.prefs(c).getInt("widget-action-page-"+id,0)+"|"+Store.prefs(c).getString("widget-selected-"+id,"")+"|"+BitmapCards.sizes(c,manager,id,360,400).toString()+"|"+BitmapCards.dark(c)+"|"+c.getResources().getDisplayMetrics().density;synchronized(LAST_ACTION){if(key.equals(LAST_ACTION.get(id)))continue;manager.updateAppWidget(id,BitmapCards.actionViews(c,manager,id,data));LAST_ACTION.put(id,key);}}}
 static void receive(AppWidgetProvider p,Context c,Intent i){
  if(!(p instanceof ActionWidget)){DeviceWidgets.receive(p,c,i);return;}
  if("com.cxy.workbench.ACTION_CARD".equals(i.getAction())){int id=i.getIntExtra("widgetId",-1);if(id>=0){String op=i.getStringExtra("operation"),value=i.getStringExtra("value");android.content.SharedPreferences.Editor edit=Store.prefs(c).edit();if("group".equals(op)){try{int group=Integer.parseInt(value);if(group>=0&&group<5)edit.putInt("widget-page-"+id,group).putInt("widget-action-page-"+id,0).putString("widget-selected-"+id,"");}catch(NumberFormatException ignored){}}else if("mode".equals(op)&&("ring".equals(value)||"list".equals(value)))edit.putString("widget-mode-"+id,value).putInt("widget-action-page-"+id,0);else if("page".equals(op)){try{edit.putInt("widget-action-page-"+id,Math.max(0,Integer.parseInt(value)));}catch(NumberFormatException ignored){}}else if("select".equals(op)){String old=Store.prefs(c).getString("widget-selected-"+id,"");edit.putString("widget-selected-"+id,old.equals(value)?"":value);}else if("cycle".equals(op))edit.putInt("widget-page-"+id,(Store.prefs(c).getInt("widget-page-"+id,0)+1)%5).putInt("widget-action-page-"+id,0);edit.apply();if("open".equals(op))c.startActivity(new Intent(c,MainActivity.class).putExtra("tab","actions").putExtra("actionGroup",Store.prefs(c).getInt("widget-page-"+id,0)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));if("refresh".equals(op)){BroadcastReceiver.PendingResult result=p.goAsync();Store.refresh(c,true,result::finish);}updateAll(c);}return;}
  if("com.cxy.workbench.CYCLE".equals(i.getAction())){int id=i.getIntExtra("widgetId",-1);if(id>=0)Store.prefs(c).edit().putInt("widget-page-"+id,(Store.prefs(c).getInt("widget-page-"+id,0)+1)%4).apply();}
  updateAll(c);
  if("com.cxy.workbench.REFRESH".equals(i.getAction())||AppWidgetManager.ACTION_APPWIDGET_UPDATE.equals(i.getAction())){
   BroadcastReceiver.PendingResult result=p.goAsync();Store.refresh(c,true,result::finish);
  }
 }
}
